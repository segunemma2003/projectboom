import json
import boto3
import os
from datetime import datetime
from typing import Dict, Any

def handler(event: Dict[str, Any], context: Any) -> Dict[str, Any]:
    """
    API for managing notification preferences and history.
    """
    
    # Initialize AWS clients
    dynamodb = boto3.resource('dynamodb')
    
    # Environment variables
    preferences_table_name = os.environ['PREFERENCES_TABLE']
    history_table_name = os.environ['HISTORY_TABLE']
    
    try:
        # Parse API Gateway event
        http_method = event.get('httpMethod', event.get('requestContext', {}).get('http', {}).get('method', 'GET'))
        path = event.get('path', event.get('rawPath', ''))
        path_parameters = event.get('pathParameters') or {}
        query_parameters = event.get('queryStringParameters') or {}
        body = event.get('body', '{}')
        
        if body:
            try:
                body_data = json.loads(body)
            except json.JSONDecodeError:
                body_data = {}
        else:
            body_data = {}
        
        # Route to appropriate handler
        if '/preferences/' in path and http_method == 'GET':
            return get_preferences(preferences_table_name, path_parameters.get('user_id'))
        elif '/preferences/' in path and http_method == 'PUT':
            return update_preferences(preferences_table_name, path_parameters.get('user_id'), body_data)
        elif '/send' in path and http_method == 'POST':
            return send_notification(body_data)
        elif '/history/' in path and http_method == 'GET':
            return get_notification_history(history_table_name, path_parameters.get('user_id'), query_parameters)
        else:
            return {
                'statusCode': 404,
                'headers': {'Content-Type': 'application/json'},
                'body': json.dumps({'error': 'Endpoint not found'})
            }
            
    except Exception as e:
        print(f"Error in notification API: {str(e)}")
        return {
            'statusCode': 500,
            'headers': {'Content-Type': 'application/json'},
            'body': json.dumps({'error': 'Internal server error'})
        }

def get_preferences(table_name: str, user_id: str) -> Dict:
    """Get user's notification preferences"""
    try:
        if not user_id:
            return {
                'statusCode': 400,
                'headers': {'Content-Type': 'application/json'},
                'body': json.dumps({'error': 'user_id is required'})
            }
        
        dynamodb = boto3.resource('dynamodb')
        table = dynamodb.Table(table_name)
        
        # Get all preferences for the user
        response = table.query(
            KeyConditionExpression='user_id = :user_id',
            ExpressionAttributeValues={':user_id': user_id}
        )
        
        preferences = {}
        for item in response.get('Items', []):
            preferences[item['notification_type']] = {
                'enabled': item.get('enabled', True),
                'updated_at': item.get('updated_at', '')
            }
        
        # Set defaults for missing preferences
        default_preferences = ['push', 'email', 'sms', 'in_app']
        for pref_type in default_preferences:
            if pref_type not in preferences:
                preferences[pref_type] = {'enabled': True if pref_type in ['push', 'in_app'] else False}
        
        return {
            'statusCode': 200,
            'headers': {'Content-Type': 'application/json'},
            'body': json.dumps({
                'user_id': user_id,
                'preferences': preferences
            })
        }
        
    except Exception as e:
        print(f"Error getting preferences: {str(e)}")
        return {
            'statusCode': 500,
            'headers': {'Content-Type': 'application/json'},
            'body': json.dumps({'error': str(e)})
        }

def update_preferences(table_name: str, user_id: str, preferences_data: Dict) -> Dict:
    """Update user's notification preferences"""
    try:
        if not user_id:
            return {
                'statusCode': 400,
                'headers': {'Content-Type': 'application/json'},
                'body': json.dumps({'error': 'user_id is required'})
            }
        
        dynamodb = boto3.resource('dynamodb')
        table = dynamodb.Table(table_name)
        
        preferences = preferences_data.get('preferences', {})
        updated_count = 0
        
        for notification_type, settings in preferences.items():
            if notification_type not in ['push', 'email', 'sms', 'in_app']:
                continue
            
            table.put_item(
                Item={
                    'user_id': user_id,
                    'notification_type': notification_type,
                    'enabled': bool(settings.get('enabled', True)),
                    'updated_at': datetime.utcnow().isoformat()
                }
            )
            updated_count += 1
        
        return {
            'statusCode': 200,
            'headers': {'Content-Type': 'application/json'},
            'body': json.dumps({
                'message': f'Updated {updated_count} preferences',
                'user_id': user_id
            })
        }
        
    except Exception as e:
        print(f"Error updating preferences: {str(e)}")
        return {
            'statusCode': 500,
            'headers': {'Content-Type': 'application/json'},
            'body': json.dumps({'error': str(e)})
        }

def send_notification(notification_data: Dict) -> Dict:
    """Send a notification"""
    try:
        # Basic validation
        required_fields = ['user_id', 'type', 'title', 'content']
        for field in required_fields:
            if field not in notification_data:
                return {
                    'statusCode': 400,
                    'headers': {'Content-Type': 'application/json'},
                    'body': json.dumps({'error': f'{field} is required'})
                }
        
        # In a real implementation, this would add the notification to a queue
        # For now, just return success
        
        return {
            'statusCode': 200,
            'headers': {'Content-Type': 'application/json'},
            'body': json.dumps({
                'message': 'Notification queued for delivery',
                'notification_id': f"notif_{int(datetime.utcnow().timestamp())}"
            })
        }
        
    except Exception as e:
        print(f"Error sending notification: {str(e)}")
        return {
            'statusCode': 500,
            'headers': {'Content-Type': 'application/json'},
            'body': json.dumps({'error': str(e)})
        }

def get_notification_history(table_name: str, user_id: str, query_params: Dict) -> Dict:
    """Get user's notification history"""
    try:
        if not user_id:
            return {
                'statusCode': 400,
                'headers': {'Content-Type': 'application/json'},
                'body': json.dumps({'error': 'user_id is required'})
            }
        
        dynamodb = boto3.resource('dynamodb')
        table = dynamodb.Table(table_name)
        
        limit = min(int(query_params.get('limit', 50)), 100)
        
        # Query user's notification history
        response = table.query(
            IndexName='UserNotificationsIndex',
            KeyConditionExpression='user_id = :user_id',
            ExpressionAttributeValues={':user_id': user_id},
            ScanIndexForward=False,  # Most recent first
            Limit=limit
        )
        
        notifications = []
        for item in response.get('Items', []):
            notifications.append({
                'notification_id': item['notification_id'],
                'timestamp': item['timestamp'],
                'type': item.get('notification_type', ''),
                'title': item.get('title', ''),
                'content': item.get('body', item.get('content', '')),
                'status': item.get('status', '')
            })
        
        return {
            'statusCode': 200,
            'headers': {'Content-Type': 'application/json'},
            'body': json.dumps({
                'user_id': user_id,
                'notifications': notifications,
                'count': len(notifications)
            })
        }
        
    except Exception as e:
        print(f"Error getting notification history: {str(e)}")
        return {
            'statusCode': 500,
            'headers': {'Content-Type': 'application/json'},
            'body': json.dumps({'error': str(e)})
        }

def should_send_notification(table_name: str, user_id: str, notification_type: str) -> bool:
    """Check if user wants to receive this type of notification"""
    try:
        dynamodb = boto3.resource('dynamodb')
        table = dynamodb.Table(table_name)
        
        response = table.get_item(
            Key={
                'user_id': user_id,
                'notification_type': notification_type
            }
        )
        
        if 'Item' in response:
            return response['Item'].get('enabled', True)
        
        # Default to enabled if no preference set
        return True
        
    except Exception as e:
        print(f"Error checking notification preferences: {str(e)}")
        return True  # Default to sending if error

def send_push_notification(user_id: str, title: str, body: str, data: Dict, fcm_server_key: str) -> Dict:
    """Send push notification via FCM"""
    try:
        import requests
        
        # Get user's device tokens (simplified - would query user table)
        device_tokens = get_user_device_tokens(user_id)
        
        if not device_tokens:
            return {'success': False, 'error': 'No device tokens found'}
        
        # FCM payload
        fcm_payload = {
            'registration_ids': device_tokens,
            'notification': {
                'title': title,
                'body': body,
                'sound': 'default',
                'badge': '1'
            },
            'data': data,
            'priority': 'high'
        }
        
        # Send to FCM
        headers = {
            'Authorization': f'key={fcm_server_key}',
            'Content-Type': 'application/json'
        }
        
        response = requests.post(
            'https://fcm.googleapis.com/fcm/send',
            headers=headers,
            json=fcm_payload,
            timeout=30
        )
        
        if response.status_code == 200:
            return {'success': True, 'response': response.json()}
        else:
            return {'success': False, 'error': f'FCM error: {response.status_code}'}
            
    except Exception as e:
        return {'success': False, 'error': str(e)}

def get_user_device_tokens(user_id: str) -> List[str]:
    """Get user's device tokens from database"""
    # Simplified implementation - in production, query user devices table
    # This would typically be stored in a separate DynamoDB table
    return []

def record_notification_history(history_table_name: str, user_id: str, notification_type: str, 
                               title: str, body: str, status: str, error: str = None):
    """Record notification in history table"""
    try:
        dynamodb = boto3.resource('dynamodb')
        table = dynamodb.Table(history_table_name)
        
        notification_id = f"{user_id}_{int(datetime.utcnow().timestamp())}"
        timestamp = datetime.utcnow().isoformat()
        
        item = {
            'notification_id': notification_id,
            'timestamp': timestamp,
            'user_id': user_id,
            'notification_type': notification_type,
            'title': title,
            'body': body,
            'status': status,
            'expires_at': int(datetime.utcnow().timestamp()) + (30 * 24 * 60 * 60)  # 30 days TTL
        }
        
        if error:
            item['error'] = error
        
        table.put_item(Item=item)
        
    except Exception as e:
        print(f"Error recording notification history: {str(e)}")