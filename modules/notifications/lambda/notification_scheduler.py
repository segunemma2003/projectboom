import json
import boto3
import redis
import os
from datetime import datetime, timedelta
from typing import Dict, Any, List

def handler(event: Dict[str, Any], context: Any) -> Dict[str, Any]:
    """
    Schedule and batch notifications to optimize delivery and respect rate limits.
    """
    
    # Initialize clients
    dynamodb = boto3.resource('dynamodb')
    sqs = boto3.client('sqs')
    
    # Environment variables
    preferences_table_name = os.environ['PREFERENCES_TABLE']
    history_table_name = os.environ['HISTORY_TABLE']
    processing_queue_url = os.environ['PROCESSING_QUEUE']
    priority_queue_url = os.environ['PRIORITY_QUEUE']
    redis_endpoint = os.environ['REDIS_ENDPOINT']
    batch_size = int(os.environ.get('BATCH_SIZE', '50'))
    rate_limit_per_user = int(os.environ.get('RATE_LIMIT_PER_USER', '10'))
    
    try:
        # Connect to Redis
        redis_client = redis.Redis(
            host=redis_endpoint.split(':')[0],
            port=int(redis_endpoint.split(':')[1]) if ':' in redis_endpoint else 6379,
            decode_responses=True
        )
        
        # Process pending notifications
        processed_count = process_pending_notifications(
            redis_client=redis_client,
            sqs_client=sqs,
            processing_queue_url=processing_queue_url,
            priority_queue_url=priority_queue_url,
            batch_size=batch_size,
            rate_limit_per_user=rate_limit_per_user
        )
        
        # Clean up old rate limit data
        cleanup_rate_limits(redis_client)
        
        # Clean up old notification data
        cleanup_old_notifications(redis_client)
        
        return {
            'statusCode': 200,
            'body': json.dumps({
                'processed_batches': processed_count,
                'timestamp': datetime.utcnow().isoformat()
            })
        }
        
    except Exception as e:
        print(f"Error in notification scheduler: {str(e)}")
        return {
            'statusCode': 500,
            'body': json.dumps({'error': str(e)})
        }

def process_pending_notifications(redis_client, sqs_client, processing_queue_url: str, 
                                priority_queue_url: str, batch_size: int, 
                                rate_limit_per_user: int) -> int:
    """Process pending notifications from Redis queues"""
    processed_batches = 0
    
    try:
        # Process priority notifications first
        priority_notifications = get_pending_notifications(redis_client, 'priority', batch_size)
        if priority_notifications:
            send_notifications_to_queue(
                sqs_client=sqs_client,
                queue_url=priority_queue_url,
                notifications=priority_notifications,
                is_fifo=True
            )
            processed_batches += 1
        
        # Process regular notifications
        regular_notifications = get_pending_notifications(redis_client, 'regular', batch_size)
        if regular_notifications:
            # Apply rate limiting
            filtered_notifications = apply_rate_limiting(
                redis_client=redis_client,
                notifications=regular_notifications,
                rate_limit_per_user=rate_limit_per_user
            )
            
            if filtered_notifications:
                send_notifications_to_queue(
                    sqs_client=sqs_client,
                    queue_url=processing_queue_url,
                    notifications=filtered_notifications,
                    is_fifo=False
                )
                processed_batches += 1
        
        return processed_batches
        
    except Exception as e:
        print(f"Error processing pending notifications: {str(e)}")
        return 0

def get_pending_notifications(redis_client, queue_type: str, batch_size: int) -> List[Dict]:
    """Get pending notifications from Redis"""
    try:
        queue_key = f"notification_queue:{queue_type}"
        notifications = []
        
        # Get batch of notifications
        for _ in range(batch_size):
            notification_data = redis_client.rpop(queue_key)
            if not notification_data:
                break
            
            try:
                notification = json.loads(notification_data)
                notifications.append(notification)
            except json.JSONDecodeError:
                print(f"Invalid notification data: {notification_data}")
                continue
        
        return notifications
        
    except Exception as e:
        print(f"Error getting pending notifications: {str(e)}")
        return []

def apply_rate_limiting(redis_client, notifications: List[Dict], rate_limit_per_user: int) -> List[Dict]:
    """Apply rate limiting per user"""
    try:
        filtered_notifications = []
        current_hour = datetime.utcnow().hour
        
        for notification in notifications:
            user_id = notification.get('user_id')
            if not user_id:
                continue
            
            # Check rate limit for this user
            rate_limit_key = f"rate_limit:{user_id}:{current_hour}"
            current_count = redis_client.get(rate_limit_key) or 0
            current_count = int(current_count)
            
            if current_count < rate_limit_per_user:
                # Allow notification
                filtered_notifications.append(notification)
                
                # Increment rate limit counter
                redis_client.incr(rate_limit_key)
                redis_client.expire(rate_limit_key, 3600)  # Expire in 1 hour
            else:
                # Rate limit exceeded - defer notification
                defer_notification(redis_client, notification)
        
        return filtered_notifications
        
    except Exception as e:
        print(f"Error applying rate limiting: {str(e)}")
        return notifications

def defer_notification(redis_client, notification: Dict):
    """Defer notification to next hour"""
    try:
        deferred_queue_key = "notification_queue:deferred"
        redis_client.lpush(deferred_queue_key, json.dumps(notification))
        redis_client.expire(deferred_queue_key, 24 * 3600)  # Expire in 24 hours
    except Exception as e:
        print(f"Error deferring notification: {str(e)}")

def send_notifications_to_queue(sqs_client, queue_url: str, notifications: List[Dict], is_fifo: bool):
    """Send notifications to SQS queue"""
    try:
        entries = []
        
        for i, notification in enumerate(notifications):
            entry = {
                'Id': str(i),
                'MessageBody': json.dumps(notification)
            }
            
            if is_fifo:
                # For FIFO queues, add group ID and deduplication ID
                entry['MessageGroupId'] = notification.get('user_id', 'default')
                entry['MessageDeduplicationId'] = f"{notification.get('user_id', 'default')}_{int(datetime.utcnow().timestamp())}_{i}"
            
            entries.append(entry)
        
        # Send in batches of 10 (SQS limit)
        for i in range(0, len(entries), 10):
            batch = entries[i:i+10]
            sqs_client.send_message_batch(
                QueueUrl=queue_url,
                Entries=batch
            )
        
    except Exception as e:
        print(f"Error sending notifications to queue: {str(e)}")

def cleanup_rate_limits(redis_client):
    """Clean up expired rate limit keys"""
    try:
        # Get all rate limit keys
        rate_limit_keys = redis_client.keys("rate_limit:*")
        
        # Remove keys older than 24 hours
        current_time = datetime.utcnow()
        for key in rate_limit_keys:
            try:
                ttl = redis_client.ttl(key)
                if ttl == -1 or ttl > 86400:  # No TTL or TTL > 24 hours
                    redis_client.delete(key)
            except Exception as e:
                print(f"Error cleaning up rate limit key {key}: {str(e)}")
                
    except Exception as e:
        print(f"Error in rate limit cleanup: {str(e)}")

def cleanup_old_notifications(redis_client):
    """Clean up old notification data"""
    try:
        # Clean up old user notification inboxes
        user_notification_keys = redis_client.keys("user_notifications:*")
        for key in user_notification_keys:
            try:
                # Keep only last 50 notifications per user
                redis_client.ltrim(key, 0, 49)
            except Exception as e:
                print(f"Error cleaning up notification inbox {key}: {str(e)}")
        
        # Clean up old WebSocket message queues
        websocket_message_keys = redis_client.keys("websocket_message:*")
        for key in websocket_message_keys:
            try:
                # Check if key has TTL, if not, set one
                ttl = redis_client.ttl(key)
                if ttl == -1:
                    redis_client.expire(key, 3600)  # 1 hour
            except Exception as e:
                print(f"Error cleaning up websocket message {key}: {str(e)}")
                
    except Exception as e:
        print(f"Error in notification cleanup: {str(e)}")