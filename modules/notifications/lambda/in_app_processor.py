import json
import boto3
import redis
import os
from datetime import datetime
from typing import Dict, Any

def handler(event: Dict[str, Any], context: Any) -> Dict[str, Any]:
    """
    Process in-app notifications and send via WebSocket.
    """
    
    # Initialize clients
    dynamodb = boto3.resource('dynamodb')
    
    # Environment variables
    preferences_table_name = os.environ['PREFERENCES_TABLE']
    history_table_name = os.environ['HISTORY_TABLE']
    redis_endpoint = os.environ['REDIS_ENDPOINT']
    websocket_api_endpoint = os.environ.get('WEBSOCKET_API_ENDPOINT', '')
    
    try:
        # Connect to Redis
        redis_client = redis.Redis(
            host=redis_endpoint.split(':')[0],
            port=int(redis_endpoint.split(':')[1]) if ':' in redis_endpoint else 6379,
            decode_responses=True
        )
        
        processed_count = 0
        failed_count = 0
        
        for record in event.get('Records', []):
            try:
                # Parse message
                if 'body' in record:
                    message = json.loads(record['body'])
                elif 'Sns' in record:
                    message = json.loads(record['Sns']['Message'])
                else:
                    continue
                
                user_id = message.get('user_id')
                notification_data = {
                    'id': f"notif_{int(datetime.utcnow().timestamp())}",
                    'type': message.get('type', 'info'),
                    'title': message.get('title', ''),
                    'content': message.get('content', ''),
                    'data': message.get('data', {}),
                    'timestamp': datetime.utcnow().isoformat(),
                    'read': False
                }
                
                if not user_id:
                    continue
                
                # Check preferences
                if should_send_in_app(preferences_table_name, user_id, 'in_app'):
                    # Send via WebSocket to active connections
                    result = send_websocket_notification(
                        redis_client=redis_client,
                        user_id=user_id,
                        notification_data=notification_data
                    )
                    
                    # Store in user's notification inbox
                    store_in_app_notification(
                        redis_client=redis_client,
                        user_id=user_id,
                        notification_data=notification_data
                    )
                    
                    # Record history
                    record_in_app_history(
                        history_table_name=history_table_name,
                        user_id=user_id,
                        notification_data=notification_data,
                        status='sent' if result['success'] else 'failed',
                        error=result.get('error')
                    )
                    
                    if result['success']:
                        processed_count += 1
                    else:
                        failed_count += 1
                        
            except Exception as e:
                print(f"Error processing in-app record: {str(e)}")
                failed_count += 1
        
        return {
            'statusCode': 200,
            'body': json.dumps({
                'processed': processed_count,
                'failed': failed_count
            })
        }
        
    except Exception as e:
        print(f"Error in in-app processor: {str(e)}")
        return {
            'statusCode': 500,
            'body': json.dumps({'error': str(e)})
        }

def should_send_in_app(table_name: str, user_id: str, notification_type: str) -> bool:
    """Check in-app preferences"""
    try:
        dynamodb = boto3.resource('dynamodb')
        table = dynamodb.Table(table_name)
        
        response = table.get_item(
            Key={
                'user_id': user_id,
                'notification_type': notification_type
            }
        )
        
        return response.get('Item', {}).get('enabled', True)
        
    except Exception as e:
        print(f"Error checking in-app preferences: {str(e)}")
        return True

def send_websocket_notification(redis_client, user_id: str, notification_data: Dict) -> Dict:
    """Send notification via WebSocket to active connections"""
    try:
        # Get user's active WebSocket connections from Redis
        connection_key = f"websocket_connections:{user_id}"
        connections = redis_client.smembers(connection_key)
        
        if not connections:
            return {'success': True, 'message': 'No active connections'}
        
        # Send to each active connection
        successful_sends = 0
        for connection_id in connections:
            try:
                # In a real implementation, you'd use API Gateway Management API
                # to send to specific WebSocket connections
                notification_message = {
                    'type': 'notification',
                    'data': notification_data
                }
                
                # Store message for connection to pick up
                message_key = f"websocket_message:{connection_id}"
                redis_client.lpush(message_key, json.dumps(notification_message))
                redis_client.expire(message_key, 3600)  # Expire in 1 hour
                
                successful_sends += 1
                
            except Exception as e:
                print(f"Error sending to connection {connection_id}: {str(e)}")
        
        return {
            'success': True, 
            'sent_to': successful_sends,
            'total_connections': len(connections)
        }
        
    except Exception as e:
        return {'success': False, 'error': str(e)}

def store_in_app_notification(redis_client, user_id: str, notification_data: Dict):
    """Store notification in user's inbox"""
    try:
        inbox_key = f"user_notifications:{user_id}"
        
        # Add to user's notification list
        redis_client.lpush(inbox_key, json.dumps(notification_data))
        
        # Keep only last 100 notifications
        redis_client.ltrim(inbox_key, 0, 99)
        
        # Set expiry for the inbox (30 days)
        redis_client.expire(inbox_key, 30 * 24 * 60 * 60)
        
        # Update unread count
        unread_key = f"unread_notifications:{user_id}"
        redis_client.incr(unread_key)
        redis_client.expire(unread_key, 30 * 24 * 60 * 60)
        
    except Exception as e:
        print(f"Error storing in-app notification: {str(e)}")

def record_in_app_history(history_table_name: str, user_id: str, notification_data: Dict, 
                         status: str, error: str = None):
    """Record in-app notification in history"""
    try:
        dynamodb = boto3.resource('dynamodb')
        table = dynamodb.Table(history_table_name)
        
        notification_id = notification_data['id']
        timestamp = datetime.utcnow().isoformat()
        
        item = {
            'notification_id': notification_id,
            'timestamp': timestamp,
            'user_id': user_id,
            'notification_type': 'in_app',
            'title': notification_data.get('title', ''),
            'content': notification_data.get('content', ''),
            'status': status,
            'expires_at': int(datetime.utcnow().timestamp()) + (30 * 24 * 60 * 60)
        }
        
        if error:
            item['error'] = error
        
        table.put_item(Item=item)
        
    except Exception as e:
        print(f"Error recording in-app history: {str(e)}")