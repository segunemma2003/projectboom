import json
import boto3
import os
from datetime import datetime, timezone
from decimal import Decimal

# Initialize AWS clients
dynamodb = boto3.resource('dynamodb')
sns = boto3.client('sns')

# Environment variables
CHAT_MESSAGES_TABLE = os.environ['CHAT_MESSAGES_TABLE']
CONVERSATIONS_TABLE = os.environ['CONVERSATIONS_TABLE']
USER_CONVERSATIONS_TABLE = os.environ['USER_CONVERSATIONS_TABLE']
USER_PRESENCE_TABLE = os.environ['USER_PRESENCE_TABLE']
CHAT_NOTIFICATIONS_TOPIC = os.environ['CHAT_NOTIFICATIONS_TOPIC']
GROUP_NOTIFICATIONS_TOPIC = os.environ['GROUP_NOTIFICATIONS_TOPIC']

def handler(event, context):
    """
    Process chat messages from SQS queue
    """
    try:
        # Get tables
        messages_table = dynamodb.Table(CHAT_MESSAGES_TABLE)
        conversations_table = dynamodb.Table(CONVERSATIONS_TABLE)
        user_conversations_table = dynamodb.Table(USER_CONVERSATIONS_TABLE)
        
        for record in event['Records']:
            # Parse SQS message
            message_body = json.loads(record['body'])
            
            # Extract message data
            conversation_id = message_body['conversation_id']
            user_id = message_body['user_id']
            message_content = message_body['content']
            message_type = message_body.get('message_type', 'text')
            timestamp = datetime.now(timezone.utc).isoformat()
            
            # Create composite sort key
            timestamp_message_id = f"{timestamp}#{record['messageId']}"
            
            # Store message in DynamoDB
            message_item = {
                'conversation_id': conversation_id,
                'timestamp_message_id': timestamp_message_id,
                'user_id': user_id,
                'content': message_content,
                'message_type': message_type,
                'timestamp': timestamp,
                'message_id': record['messageId']
            }
            
            # Add TTL if enabled (7 days from now)
            if 'ttl' in message_body:
                message_item['ttl'] = int((datetime.now(timezone.utc).timestamp()) + 604800)
            
            messages_table.put_item(Item=message_item)
            
            # Update conversation last activity
            conversations_table.update_item(
                Key={'conversation_id': conversation_id},
                UpdateExpression='SET last_activity = :timestamp, last_message_preview = :preview',
                ExpressionAttributeValues={
                    ':timestamp': timestamp,
                    ':preview': message_content[:100] if message_type == 'text' else f'[{message_type}]'
                }
            )
            
            # Update user conversation read status
            user_conversations_table.update_item(
                Key={
                    'user_id': user_id,
                    'conversation_id': conversation_id
                },
                UpdateExpression='SET last_sent_timestamp = :timestamp',
                ExpressionAttributeValues={':timestamp': timestamp}
            )
            
            # Send notifications
            notification_message = {
                'conversation_id': conversation_id,
                'user_id': user_id,
                'message_type': message_type,
                'timestamp': timestamp,
                'message_id': record['messageId']
            }
            
            # Determine which SNS topic to use
            topic_arn = GROUP_NOTIFICATIONS_TOPIC if message_body.get('is_group', False) else CHAT_NOTIFICATIONS_TOPIC
            
            sns.publish(
                TopicArn=topic_arn,
                Message=json.dumps(notification_message),
                MessageAttributes={
                    'conversation_id': {
                        'DataType': 'String',
                        'StringValue': conversation_id
                    },
                    'message_type': {
                        'DataType': 'String',
                        'StringValue': message_type
                    }
                }
            )
        
        return {
            'statusCode': 200,
            'body': json.dumps(f'Processed {len(event["Records"])} messages successfully')
        }
        
    except Exception as e:
        print(f"Error processing messages: {str(e)}")
        raise e