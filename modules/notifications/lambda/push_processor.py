mport json
import boto3
import os
from datetime import datetime
from typing import Dict, Any, List

def handler(event: Dict[str, Any], context: Any) -> Dict[str, Any]:
    """
    Process push notifications for social media platform users.
    Handles FCM (Android) and APNS (iOS) push notifications.
    """
    
    # Initialize AWS clients
    dynamodb = boto3.resource('dynamodb')
    sns = boto3.client('sns')
    
    # Environment variables
    preferences_table_name = os.environ['PREFERENCES_TABLE']
    history_table_name = os.environ['HISTORY_TABLE']
    fcm_server_key = os.environ.get('FCM_SERVER_KEY', '')
    max_batch_size = int(os.environ.get('MAX_BATCH_SIZE', '100'))
    
    try:
        processed_count = 0
        failed_count = 0
        
        # Process each record from SQS/SNS
        for record in event.get('Records', []):
            try:
                # Parse message body
                if 'body' in record:
                    # SQS message
                    message = json.loads(record['body'])
                elif 'Sns' in record:
                    # SNS message
                    message = json.loads(record['Sns']['Message'])
                else:
                    continue
                
                # Extract notification data
                user_id = message.get('user_id')
                notification_type = message.get('type', 'default')
                title = message.get('title', 'New Notification')
                body = message.get('body', '')
                data = message.get('data', {})
                
                if not user_id:
                    continue
                
                # Check user preferences
                if should_send_notification(preferences_table_name, user_id, notification_type):
                    # Send push notification
                    result = send_push_notification(
                        user_id=user_id,
                        title=title,
                        body=body,
                        data=data,
                        fcm_server_key=fcm_server_key
                    )
                    
                    # Record in history
                    record_notification_history(
                        history_table_name=history_table_name,
                        user_id=user_id,
                        notification_type=notification_type,
                        title=title,
                        body=body,
                        status='sent' if result['success'] else 'failed',
                        error=result.get('error')
                    )
                    
                    if result['success']:
                        processed_count += 1
                    else:
                        failed_count += 1
                else:
                    # User opted out - record as skipped
                    record_notification_history(
                        history_table_name=history_table_name,
                        user_id=user_id,
                        notification_type=notification_type,
                        title=title,
                        body=body,
                        status='skipped',
                        error='User opted out'
                    )
                    
            except Exception as e:
                print(f"Error processing record: {str(e)}")
                failed_count += 1
        
        return {
            'statusCode': 200,
            'body': json.dumps({
                'processed': processed_count,
                'failed': failed_count,
                'total': len(event.get('Records', []))
            })
        }
        
    except Exception as e:
        print(f"Error in push processor: {str(e)}")
        return {
            'statusCode': 500,
            'body': json.dumps({'error': str(e)})
        }

def should_send_sms(table_name: str, user_id: str, notification_type: str) -> bool:
    """Check SMS preferences"""
    try:
        dynamodb = boto3.resource('dynamodb')
        table = dynamodb.Table(table_name)
        
        response = table.get_item(
            Key={
                'user_id': user_id,
                'notification_type': notification_type
            }
        )
        
        return response.get('Item', {}).get('enabled', False)  # SMS defaults to disabled
        
    except Exception as e:
        print(f"Error checking SMS preferences: {str(e)}")
        return False

def send_sms(sns_client, phone_number: str, message: str, sender_id: str) -> Dict:
    """Send SMS via SNS"""
    try:
        response = sns_client.publish(
            PhoneNumber=phone_number,
            Message=message,
            MessageAttributes={
                'AWS.SNS.SMS.SenderID': {
                    'DataType': 'String',
                    'StringValue': sender_id
                },
                'AWS.SNS.SMS.SMSType': {
                    'DataType': 'String',
                    'StringValue': 'Transactional'
                }
            }
        )
        return {'success': True, 'message_id': response['MessageId']}
    except Exception as e:
        return {'success': False, 'error': str(e)}

def record_sms_history(history_table_name: str, user_id: str, phone_number: str, 
                      content: str, status: str, error: str = None):
    """Record SMS in history"""
    try:
        dynamodb = boto3.resource('dynamodb')
        table = dynamodb.Table(history_table_name)
        
        notification_id = f"sms_{user_id}_{int(datetime.utcnow().timestamp())}"
        timestamp = datetime.utcnow().isoformat()
        
        item = {
            'notification_id': notification_id,
            'timestamp': timestamp,
            'user_id': user_id,
            'notification_type': 'sms',
            'phone_number': phone_number,
            'content': content,
            'status': status,
            'expires_at': int(datetime.utcnow().timestamp()) + (30 * 24 * 60 * 60)
        }
        
        if error:
            item['error'] = error
        
        table.put_item(Item=item)
        
    except Exception as e:
        print(f"Error recording SMS history: {str(e)}")
