import json
import boto3
import os
from datetime import datetime, timezone, timedelta
from typing import Dict, Any, List

# Initialize AWS clients
dynamodb = boto3.resource('dynamodb')
s3 = boto3.client('s3')
sns = boto3.client('sns')

def handler(event: Dict[str, Any], context: Any) -> Dict[str, Any]:
    """
    Lambda function for automated data retention processing.
    
    Handles:
    - Automated deletion of expired data based on retention policies
    - Data archival to cheaper storage classes
    - Compliance reporting
    """
    
    try:
        print("Starting data retention processing...")
        
        # Get retention policies
        retention_policies = json.loads(os.environ.get('RETENTION_POLICIES', '{}'))
        
        results = {
            'processed_at': datetime.utcnow().isoformat(),
            'retention_results': {}
        }
        
        # Process each retention policy
        for data_type, retention_rule in retention_policies.items():
            print(f"Processing retention for {data_type}: {retention_rule}")
            results['retention_results'][data_type] = process_retention_policy(data_type, retention_rule)
        
        # Archive old audit logs
        results['audit_archival'] = archive_old_audit_logs()
        
        # Clean up expired consent records
        results['consent_cleanup'] = cleanup_expired_consent()
        
        # Send summary notification
        send_retention_summary(results)
        
        return {
            'statusCode': 200,
            'body': json.dumps(results)
        }
        
    except Exception as e:
        print(f"Error in data retention processing: {str(e)}")
        send_error_notification(str(e))
        return {
            'statusCode': 500,
            'body': json.dumps({'error': str(e)})
        }

def process_retention_policy(data_type: str, retention_rule: str) -> Dict[str, Any]:
    """Process retention policy for a specific data type"""
    
    result = {
        'data_type': data_type,
        'retention_rule': retention_rule,
        'processed_items': 0,
        'deleted_items': 0,
        'archived_items': 0,
        'errors': []
    }
    
    try:
        if data_type == 'chat_messages':
            result.update(process_chat_messages_retention(retention_rule))
        elif data_type == 'user_profiles':
            result.update(process_user_profiles_retention(retention_rule))
        elif data_type == 'audit_logs':
            result.update(process_audit_logs_retention(retention_rule))
        elif data_type == 'media_files':
            result.update(process_media_files_retention(retention_rule))
        else:
            result['errors'].append(f"Unknown data type: {data_type}")
            
    except Exception as e:
        result['errors'].append(str(e))
    
    return result

def process_chat_messages_retention(retention_rule: str) -> Dict[str, Any]:
    """Process chat messages retention"""
    
    result = {'processed_items': 0, 'deleted_items': 0}
    
    # Parse retention rule (e.g., "2years")
    retention_days = parse_retention_rule(retention_rule)
    cutoff_date = datetime.utcnow() - timedelta(days=retention_days)
    
    chat_table_name = os.environ.get('CHAT_MESSAGES_TABLE')
    if not chat_table_name:
        return {'error': 'Chat messages table not configured'}
    
    try:
        # This is a simplified implementation
        # In practice, you'd need to scan the table and delete old messages
        # Consider using DynamoDB TTL for automatic cleanup
        
        print(f"Processing chat messages older than {cutoff_date}")
        
        # Implementation would depend on your table structure
        # For now, return placeholder data
        result['processed_items'] = 0
        result['deleted_items'] = 0
        
    except Exception as e:
        result['error'] = str(e)
    
    return result

def process_user_profiles_retention(retention_rule: str) -> Dict[str, Any]:
    """Process user profiles retention for inactive users"""
    
    result = {'processed_items': 0, 'deleted_items': 0}
    
    # Parse retention rule (e.g., "inactive_3years")
    if retention_rule.startswith('inactive_'):
        years = int(retention_rule.split('_')[1].replace('years', ''))
        cutoff_date = datetime.utcnow() - timedelta(days=years * 365)
        
        print(f"Processing inactive user profiles older than {cutoff_date}")
        
        # Implementation would check last_activity_date in user profiles
        # and delete profiles of users inactive for the specified period
        
        result['processed_items'] = 0
        result['deleted_items'] = 0
    
    return result

def process_audit_logs_retention(retention_rule: str) -> Dict[str, Any]:
    """Process audit logs retention"""
    
    result = {'processed_items': 0, 'archived_items': 0}
    
    # Audit logs are typically kept for 7 years for GDPR compliance
    # Older logs can be archived to cheaper storage
    
    retention_days = parse_retention_rule(retention_rule)
    archive_cutoff = datetime.utcnow() - timedelta(days=retention_days - 365)  # Archive 1 year before deletion
    
    print(f"Processing audit logs for archival older than {archive_cutoff}")
    
    # Implementation would move old audit logs to S3 Glacier
    result['processed_items'] = 0
    result['archived_items'] = 0
    
    return result

def process_media_files_retention(retention_rule: str) -> Dict[str, Any]:
    """Process media files retention"""
    
    result = {'processed_items': 0, 'archived_items': 0}
    
    if retention_rule == 'user_controlled':
        # Media files are only deleted when user explicitly requests deletion
        # or when the user account is deleted
        print("Media files are user-controlled, no automatic deletion")
        return result
    
    # Process S3 objects based on retention policy
    user_data_buckets = json.loads(os.environ.get('USER_DATA_BUCKETS', '[]'))
    
    for bucket_name in user_data_buckets:
        try:
            result.update(process_s3_bucket_retention(bucket_name, retention_rule))
        except Exception as e:
            if 'errors' not in result:
                result['errors'] = []
            result['errors'].append(f"Error processing bucket {bucket_name}: {str(e)}")
    
    return result

def process_s3_bucket_retention(bucket_name: str, retention_rule: str) -> Dict[str, Any]:
    """Process S3 bucket retention policies"""
    
    result = {'processed_items': 0, 'archived_items': 0}
    
    try:
        # List objects in the bucket
        paginator = s3.get_paginator('list_objects_v2')
        pages = paginator.paginate(Bucket=bucket_name)
        
        retention_days = parse_retention_rule(retention_rule)
        cutoff_date = datetime.utcnow() - timedelta(days=retention_days)
        
        for page in pages:
            if 'Contents' not in page:
                continue
                
            for obj in page['Contents']:
                result['processed_items'] += 1
                
                # Check if object is older than retention period
                if obj['LastModified'].replace(tzinfo=None) < cutoff_date:
                    
                    # Check current storage class
                    current_storage_class = obj.get('StorageClass', 'STANDARD')
                    
                    if current_storage_class in ['STANDARD', 'STANDARD_IA']:
                        # Transition to Glacier
                        s3.copy_object(
                            Bucket=bucket_name,
                            Key=obj['Key'],
                            CopySource={'Bucket': bucket_name, 'Key': obj['Key']},
                            StorageClass='GLACIER',
                            MetadataDirective='COPY'
                        )
                        result['archived_items'] += 1
                        
                        log_retention_action('s3_archive', {
                            'bucket': bucket_name,
                            'key': obj['Key'],
                            'old_storage_class': current_storage_class,
                            'new_storage_class': 'GLACIER'
                        })
    
    except Exception as e:
        result['error'] = str(e)
    
    return result

def archive_old_audit_logs() -> Dict[str, Any]:
    """Archive old audit logs to cheaper storage"""
    
    result = {'processed_items': 0, 'archived_items': 0}
    
    try:
        audit_table = dynamodb.Table(os.environ['AUDIT_TABLE'])
        
        # Scan for audit logs older than 2 years for archival
        two_years_ago = datetime.utcnow() - timedelta(days=730)
        
        # This is a simplified implementation
        # In practice, you'd need to scan the table efficiently
        # and export old logs to S3 for long-term storage
        
        print(f"Archiving audit logs older than {two_years_ago}")
        
        # Implementation would:
        # 1. Scan DynamoDB for old audit logs
        # 2. Export to S3 in compressed format
        # 3. Delete from DynamoDB after successful export
        
        result['processed_items'] = 0
        result['archived_items'] = 0
        
    except Exception as e:
        result['error'] = str(e)
    
    return result

def cleanup_expired_consent() -> Dict[str, Any]:
    """Clean up expired consent records using TTL"""
    
    result = {'message': 'Consent cleanup handled by DynamoDB TTL'}
    
    # DynamoDB TTL automatically handles expired consent records
    # This function can be used for additional cleanup logic if needed
    
    try:
        consent_table = dynamodb.Table(os.environ['CONSENT_TABLE'])
        
        # Log cleanup activity
        log_retention_action('consent_cleanup', {
            'table': consent_table.table_name,
            'message': 'TTL cleanup in progress'
        })
        
    except Exception as e:
        result['error'] = str(e)
    
    return result

def parse_retention_rule(retention_rule: str) -> int:
    """Parse retention rule to get number of days"""
    
    if 'years' in retention_rule:
        years = int(retention_rule.replace('years', '').split('_')[-1])
        return years * 365
    elif 'months' in retention_rule:
        months = int(retention_rule.replace('months', ''))
        return months * 30
    elif 'days' in retention_rule:
        return int(retention_rule.replace('days', ''))
    else:
        # Default to 7 years for compliance
        return 7 * 365

def log_retention_action(action_type: str, metadata: Dict[str, Any]):
    """Log retention action to audit table"""
    
    try:
        audit_table = dynamodb.Table(os.environ['AUDIT_TABLE'])
        
        current_time = datetime.utcnow().isoformat()
        log_id = f"retention_{int(datetime.utcnow().timestamp())}"
        expires_at = int((datetime.utcnow() + timedelta(days=2555)).timestamp())  # 7 years
        
        audit_table.put_item(
            Item={
                'log_id': log_id,
                'timestamp': current_time,
                'user_id': 'system',
                'action_type': action_type,
                'status': 'completed',
                'metadata': metadata,
                'expires_at': expires_at
            }
        )
        
    except Exception as e:
        print(f"Error logging retention action: {str(e)}")

def send_retention_summary(results: Dict[str, Any]):
    """Send retention processing summary notification"""
    
    notification_topic = os.environ.get('NOTIFICATION_TOPIC')
    if not notification_topic:
        return
    
    try:
        # Calculate totals
        total_processed = sum(
            result.get('processed_items', 0) 
            for result in results['retention_results'].values()
        )
        total_deleted = sum(
            result.get('deleted_items', 0) 
            for result in results['retention_results'].values()
        )
        total_archived = sum(
            result.get('archived_items', 0) 
            for result in results['retention_results'].values()
        )
        
        message = {
            'type': 'data_retention_summary',
            'processed_at': results['processed_at'],
            'summary': {
                'total_processed': total_processed,
                'total_deleted': total_deleted,
                'total_archived': total_archived
            },
            'details': results['retention_results']
        }
        
        sns.publish(
            TopicArn=notification_topic,
            Subject='Data Retention Processing Summary',
            Message=json.dumps(message, indent=2)
        )
        
    except Exception as e:
        print(f"Error sending retention summary: {str(e)}")

def send_error_notification(error_message: str):
    """Send error notification"""
    
    notification_topic = os.environ.get('NOTIFICATION_TOPIC')
    if not notification_topic:
        return
    
    try:
        message = {
            'type': 'data_retention_error',
            'timestamp': datetime.utcnow().isoformat(),
            'error': error_message
        }
        
        sns.publish(
            TopicArn=notification_topic,
            Subject='Data Retention Processing Error',
            Message=json.dumps(message)
        )
        
    except Exception as e:
        print(f"Error sending error notification: {str(e)}")

def get_inactive_users(cutoff_date: datetime) -> List[str]:
    """Get list of inactive users based on cutoff date"""
    
    # This would typically query your user activity data
    # Implementation depends on how you track user activity
    
    inactive_users = []
    
    # Placeholder implementation
    # In practice, you'd query your user activity logs or profiles
    # to find users who haven't been active since the cutoff date
    
    return inactive_users

def delete_user_data_completely(user_id: str) -> Dict[str, Any]:
    """Completely delete all data for a user (GDPR Right to Erasure)"""
    
    result = {
        'user_id': user_id,
        'deleted_from': [],
        'errors': []
    }
    
    try:
        # Delete from consent table
        consent_table = dynamodb.Table(os.environ['CONSENT_TABLE'])
        consent_table.delete_item(Key={'user_id': user_id})
        result['deleted_from'].append('consent_records')
        
        # Delete from other tables as needed
        # Implementation depends on your data model
        
        # Delete from S3 buckets
        user_data_buckets = json.loads(os.environ.get('USER_DATA_BUCKETS', '[]'))
        for bucket_name in user_data_buckets:
            try:
                delete_user_s3_data(bucket_name, user_id)
                result['deleted_from'].append(f's3_{bucket_name}')
            except Exception as e:
                result['errors'].append(f"S3 {bucket_name}: {str(e)}")
        
        # Log the complete deletion
        log_retention_action('complete_user_deletion', {
            'user_id': user_id,
            'deleted_from': result['deleted_from'],
            'errors': result['errors']
        })
        
    except Exception as e:
        result['errors'].append(str(e))
    
    return result

def delete_user_s3_data(bucket_name: str, user_id: str):
    """Delete all S3 data for a specific user"""
    
    # List all objects with user prefix
    paginator = s3.get_paginator('list_objects_v2')
    pages = paginator.paginate(Bucket=bucket_name, Prefix=f"users/{user_id}/")
    
    objects_to_delete = []
    for page in pages:
        if 'Contents' in page:
            for obj in page['Contents']:
                objects_to_delete.append({'Key': obj['Key']})
    
    # Delete objects in batches
    if objects_to_delete:
        # Delete in batches of 1000 (AWS limit)
        for i in range(0, len(objects_to_delete), 1000):
            batch = objects_to_delete[i:i+1000]
            s3.delete_objects(
                Bucket=bucket_name,
                Delete={'Objects': batch}
            )