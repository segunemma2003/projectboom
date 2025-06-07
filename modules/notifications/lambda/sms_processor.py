import json
import boto3
import os
from datetime import datetime
from typing import Dict, Any

def handler(event: Dict[str, Any], context: Any) -> Dict[str, Any]:
    """
    Process SMS notifications using Amazon SNS.
    """
    
    # Initialize AWS clients
    sns = boto3.client('sns')
    dynamodb = boto3.resource('dynamodb')
    
    # Environment variables
    preferences_table_name = os.environ['PREFERENCES_TABLE']
    history_table_name = os.environ['HISTORY_TABLE']
    sms_sender_id = os.environ.get('SMS_SENDER_ID', 'SocialApp')
    
    try:
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
                phone_number = message.get('phone_number')
                sms_content = message.get('content', '')
                
                if not user_id or not phone_number or not sms_content:
                    continue
                
                # Check preferences
                if should_send_sms(preferences_table_name, user_id, 'sms'):
                    # Send SMS
                    result = send_sms(
                        sns_client=sns,
                        phone_number=phone_number,
                        message=sms_content,
                        sender_id=sms_sender_id
                    )
                    
                    # Record history
                    record_sms_history(
                        history_table_name=history_table_name,
                        user_id=user_id,
                        phone_number=phone_number,
                        content=sms_content,
                        status='sent' if result['success'] else 'failed',
                        error=result.get('error')
                    )
                    
                    if result['success']:
                        processed_count += 1
                    else:
                        failed_count += 1
                        
            except Exception as e:
                print(f"Error processing SMS record: {str(e)}")
                failed_count += 1
        
        return {
            'statusCode': 200,
            'body': json.dumps({
                'processed': processed_count,
                'failed': failed_count
            })
        }
        
    except Exception as e:
        print(f"Error in SMS processor: {str(e)}")
        return {
            'statusCode': 500
        }