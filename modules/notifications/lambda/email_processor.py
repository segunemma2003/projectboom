import json
import boto3
import os
from datetime import datetime
from typing import Dict, Any

def handler(event: Dict[str, Any], context: Any) -> Dict[str, Any]:
    """
    Process email notifications using Amazon SES.
    """
    
    # Initialize AWS clients
    ses = boto3.client('ses')
    s3 = boto3.client('s3')
    dynamodb = boto3.resource('dynamodb')
    
    # Environment variables
    preferences_table_name = os.environ['PREFERENCES_TABLE']
    history_table_name = os.environ['HISTORY_TABLE']
    from_email = os.environ['FROM_EMAIL']
    template_bucket = os.environ['TEMPLATE_BUCKET']
    
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
                email = message.get('email')
                subject = message.get('subject', 'Notification')
                template_name = message.get('template', 'default')
                template_data = message.get('template_data', {})
                
                if not user_id or not email:
                    continue
                
                # Check preferences
                if should_send_email(preferences_table_name, user_id, 'email'):
                    # Get email template
                    template_content = get_email_template(template_bucket, template_name)
                    
                    # Render template with data
                    html_content = render_template(template_content, template_data)
                    
                    # Send email
                    result = send_email(
                        ses_client=ses,
                        from_email=from_email,
                        to_email=email,
                        subject=subject,
                        html_content=html_content
                    )
                    
                    # Record history
                    record_email_history(
                        history_table_name=history_table_name,
                        user_id=user_id,
                        email=email,
                        subject=subject,
                        status='sent' if result['success'] else 'failed',
                        error=result.get('error')
                    )
                    
                    if result['success']:
                        processed_count += 1
                    else:
                        failed_count += 1
                        
            except Exception as e:
                print(f"Error processing email record: {str(e)}")
                failed_count += 1
        
        return {
            'statusCode': 200,
            'body': json.dumps({
                'processed': processed_count,
                'failed': failed_count
            })
        }
        
    except Exception as e:
        print(f"Error in email processor: {str(e)}")
        return {
            'statusCode': 500,
            'body': json.dumps({'error': str(e)})
        }

def should_send_email(table_name: str, user_id: str, notification_type: str) -> bool:
    """Check email preferences"""
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
        print(f"Error checking email preferences: {str(e)}")
        return True

def get_email_template(bucket: str, template_name: str) -> str:
    """Get email template from S3"""
    try:
        s3 = boto3.client('s3')
        response = s3.get_object(Bucket=bucket, Key=f"templates/{template_name}.html")
        return response['Body'].read().decode('utf-8')
    except Exception as e:
        print(f"Error getting template: {str(e)}")
        return "<html><body>{{content}}</body></html>"

def render_template(template: str, data: Dict) -> str:
    """Simple template rendering"""
    try:
        for key, value in data.items():
            template = template.replace(f"{{{{{key}}}}}", str(value))
        return template
    except Exception as e:
        print(f"Error rendering template: {str(e)}")
        return template

def send_email(ses_client, from_email: str, to_email: str, subject: str, html_content: str) -> Dict:
    """Send email via SES"""
    try:
        response = ses_client.send_email(
            Source=from_email,
            Destination={'ToAddresses': [to_email]},
            Message={
                'Subject': {'Data': subject},
                'Body': {'Html': {'Data': html_content}}
            }
        )
        return {'success': True, 'message_id': response['MessageId']}
    except Exception as e:
        return {'success': False, 'error': str(e)}

def record_email_history(history_table_name: str, user_id: str, email: str, 
                        subject: str, status: str, error: str = None):
    """Record email in history"""
    try:
        dynamodb = boto3.resource('dynamodb')
        table = dynamodb.Table(history_table_name)
        
        notification_id = f"email_{user_id}_{int(datetime.utcnow().timestamp())}"
        timestamp = datetime.utcnow().isoformat()
        
        item = {
            'notification_id': notification_id,
            'timestamp': timestamp,
            'user_id': user_id,
            'notification_type': 'email',
            'subject': subject,
            'email': email,
            'status': status,
            'expires_at': int(datetime.utcnow().timestamp()) + (30 * 24 * 60 * 60)
        }
        
        if error:
            item['error'] = error
        
        table.put_item(Item=item)
        
    except Exception as e:
        print(f"Error recording email history: {str(e)}")
