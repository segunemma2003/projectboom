import json
import boto3
import redis
import os
from datetime import datetime
from typing import Dict, Any

def handler(event: Dict[str, Any], context: Any) -> Dict[str, Any]:
    """
    Lambda function to collect custom business metrics for the social media platform.
    Metrics collected:
    - Active users (from Redis)
    - Video calls in progress (from Redis)
    - Live streams active (from Redis)
    - Messages per minute (from Redis)
    - WebSocket connections (from ECS)
    """
    
    # Initialize AWS clients
    cloudwatch = boto3.client('cloudwatch')
    ecs = boto3.client('ecs')
    
    # Environment variables
    environment = os.environ.get('ENVIRONMENT', 'development')
    cluster_name = os.environ.get('CLUSTER_NAME')
    redis_endpoint = os.environ.get('REDIS_ENDPOINT')
    
    try:
        # Connect to Redis
        redis_client = redis.Redis(
            host=redis_endpoint.split(':')[0],
            port=int(redis_endpoint.split(':')[1]) if ':' in redis_endpoint else 6379,
            decode_responses=True,
            socket_timeout=5
        )
        
        # Collect business metrics from Redis
        metrics = collect_business_metrics(redis_client)
        
        # Collect infrastructure metrics
        infrastructure_metrics = collect_infrastructure_metrics(ecs, cluster_name)
        
        # Combine all metrics
        all_metrics = {**metrics, **infrastructure_metrics}
        
        # Send metrics to CloudWatch
        send_metrics_to_cloudwatch(cloudwatch, all_metrics, environment)
        
        return {
            'statusCode': 200,
            'body': json.dumps({
                'message': 'Custom metrics collected successfully',
                'metrics': all_metrics
            })
        }
        
    except Exception as e:
        print(f"Error collecting custom metrics: {str(e)}")
        return {
            'statusCode': 500,
            'body': json.dumps({
                'error': str(e)
            })
        }

def collect_business_metrics(redis_client: redis.Redis) -> Dict[str, float]:
    """Collect business metrics from Redis"""
    metrics = {}
    
    try:
        # Active users (users with activity in last 5 minutes)
        active_users = redis_client.scard('active_users')
        metrics['ActiveUsers'] = float(active_users or 0)
        
        # Video calls in progress
        video_calls = redis_client.scard('active_video_calls')
        metrics['VideoCallsInProgress'] = float(video_calls or 0)
        
        # Live streams active
        live_streams = redis_client.scard('active_live_streams')
        metrics['LiveStreamsActive'] = float(live_streams or 0)
        
        # Messages sent in last minute
        current_minute = datetime.now().strftime('%Y-%m-%d-%H-%M')
        messages_key = f'messages_count:{current_minute}'
        messages_count = redis_client.get(messages_key)
        metrics['MessagesPerMinute'] = float(messages_count or 0)
        
        # WebSocket connections
        websocket_connections = redis_client.scard('websocket_connections')
        metrics['WebSocketConnections'] = float(websocket_connections or 0)
        
        # Chat rooms active
        active_rooms = redis_client.scard('active_chat_rooms')
        metrics['ActiveChatRooms'] = float(active_rooms or 0)
        
        # Group calls active
        group_calls = redis_client.scard('active_group_calls')
        metrics['GroupCallsActive'] = float(group_calls or 0)
        
        # Queue lengths for background jobs
        message_queue_length = redis_client.llen('message_queue')
        metrics['MessageQueueLength'] = float(message_queue_length or 0)
        
        notification_queue_length = redis_client.llen('notification_queue')
        metrics['NotificationQueueLength'] = float(notification_queue_length or 0)
        
        # Media processing queue
        media_processing_queue = redis_client.llen('media_processing_queue')
        metrics['MediaProcessingQueueLength'] = float(media_processing_queue or 0)
        
        # Error rates (errors in last minute)
        error_key = f'errors:{current_minute}'
        error_count = redis_client.get(error_key)
        metrics['ErrorsPerMinute'] = float(error_count or 0)
        
        # Database connection pool usage (if stored in Redis)
        db_connections = redis_client.get('db_connection_pool_usage')
        metrics['DatabaseConnectionPoolUsage'] = float(db_connections or 0)
        
        # Cache hit rate
        cache_hits = redis_client.get('cache_hits') or 0
        cache_misses = redis_client.get('cache_misses') or 0
        total_requests = float(cache_hits) + float(cache_misses)
        if total_requests > 0:
            metrics['CacheHitRate'] = (float(cache_hits) / total_requests) * 100
        else:
            metrics['CacheHitRate'] = 0.0
            
    except Exception as e:
        print(f"Error collecting business metrics: {str(e)}")
        # Return partial metrics if some failed
        pass
    
    return metrics

def collect_infrastructure_metrics(ecs_client, cluster_name: str) -> Dict[str, float]:
    """Collect infrastructure metrics from AWS services"""
    metrics = {}
    
    try:
        if not cluster_name:
            return metrics
            
        # Get ECS service information
        services_response = ecs_client.list_services(cluster=cluster_name)
        service_arns = services_response.get('serviceArns', [])
        
        if service_arns:
            services_detail = ecs_client.describe_services(
                cluster=cluster_name,
                services=service_arns
            )
            
            total_running_tasks = 0
            total_desired_tasks = 0
            
            for service in services_detail.get('services', []):
                running_count = service.get('runningCount', 0)
                desired_count = service.get('desiredCount', 0)
                
                total_running_tasks += running_count
                total_desired_tasks += desired_count
                
                # Per-service metrics
                service_name = service.get('serviceName', '').split('-')[-1]  # Extract service type
                if service_name:
                    metrics[f'{service_name.title()}RunningTasks'] = float(running_count)
                    metrics[f'{service_name.title()}DesiredTasks'] = float(desired_count)
            
            metrics['TotalRunningTasks'] = float(total_running_tasks)
            metrics['TotalDesiredTasks'] = float(total_desired_tasks)
            
            # Task health percentage
            if total_desired_tasks > 0:
                task_health_percentage = (total_running_tasks / total_desired_tasks) * 100
                metrics['TaskHealthPercentage'] = task_health_percentage
                
    except Exception as e:
        print(f"Error collecting infrastructure metrics: {str(e)}")
    
    return metrics

def send_metrics_to_cloudwatch(cloudwatch_client, metrics: Dict[str, float], environment: str):
    """Send metrics to CloudWatch"""
    
    # Prepare metric data
    metric_data = []
    timestamp = datetime.utcnow()
    
    for metric_name, value in metrics.items():
        metric_data.append({
            'MetricName': metric_name,
            'Dimensions': [
                {
                    'Name': 'Environment',
                    'Value': environment
                }
            ],
            'Unit': 'Count' if 'Percentage' not in metric_name and 'Rate' not in metric_name else 'Percent',
            'Value': value,
            'Timestamp': timestamp
        })
    
    # Send metrics in batches (CloudWatch limit is 20 metrics per request)
    batch_size = 20
    for i in range(0, len(metric_data), batch_size):
        batch = metric_data[i:i + batch_size]
        
        try:
            cloudwatch_client.put_metric_data(
                Namespace='SocialPlatform/Business',
                MetricData=batch
            )
            print(f"Successfully sent batch of {len(batch)} metrics to CloudWatch")
            
        except Exception as e:
            print(f"Error sending metrics batch to CloudWatch: {str(e)}")
    
    print(f"Total metrics sent: {len(metrics)}")

# Health check function for monitoring the Lambda itself
def lambda_health_check() -> Dict[str, Any]:
    """Health check for the Lambda function"""
    return {
        'status': 'healthy',
        'timestamp': datetime.utcnow().isoformat(),
        'function': 'custom_metrics_collector'
    }