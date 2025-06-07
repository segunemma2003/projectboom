import json
import boto3
import os
from datetime import datetime, timezone

# Initialize AWS clients
dynamodb = boto3.resource('dynamodb')

# Environment variables
USER_PRESENCE_TABLE = os.environ['USER_PRESENCE_TABLE']

def handler(event, context):
    """
    Manage user presence status
    """
    try:
        presence_table = dynamodb.Table(USER_PRESENCE_TABLE)
        
        # Parse the event
        action = event.get('action')
        user_id = event.get('user_id')
        
        if not user_id:
            return {
                'statusCode': 400,
                'body': json.dumps('user_id is required')
            }
        
        current_timestamp = datetime.now(timezone.utc).isoformat()
        ttl_timestamp = int(datetime.now(timezone.utc).timestamp()) + 300  # 5 minutes TTL
        
        if action == 'online':
            # Set user as online
            presence_table.put_item(
                Item={
                    'user_id': user_id,
                    'status': 'online',
                    'last_seen': current_timestamp,
                    'ttl': ttl_timestamp
                }
            )
            
        elif action == 'offline':
            # Set user as offline
            presence_table.put_item(
                Item={
                    'user_id': user_id,
                    'status': 'offline',
                    'last_seen': current_timestamp,
                    'ttl': ttl_timestamp
                }
            )
            
        elif action == 'heartbeat':
            # Update last seen timestamp
            presence_table.update_item(
                Key={'user_id': user_id},
                UpdateExpression='SET last_seen = :timestamp, #ttl = :ttl',
                ExpressionAttributeNames={'#ttl': 'ttl'},
                ExpressionAttributeValues={
                    ':timestamp': current_timestamp,
                    ':ttl': ttl_timestamp
                }
            )
            
        elif action == 'get_status':
            # Get user's current status
            response = presence_table.get_item(Key={'user_id': user_id})
            
            if 'Item' in response:
                return {
                    'statusCode': 200,
                    'body': json.dumps({
                        'user_id': user_id,
                        'status': response['Item'].get('status', 'offline'),
                        'last_seen': response['Item'].get('last_seen')
                    })
                }
            else:
                return {
                    'statusCode': 200,
                    'body': json.dumps({
                        'user_id': user_id,
                        'status': 'offline',
                        'last_seen': None
                    })
                }
        
        return {
            'statusCode': 200,
            'body': json.dumps(f'Presence updated for user {user_id}')
        }
        
    except Exception as e:
        print(f"Error managing presence: {str(e)}")
        return {
            'statusCode': 500,
            'body': json.dumps(f'Error: {str(e)}')
        }