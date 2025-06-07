import json
import boto3
import os
from datetime import datetime, timedelta
from typing import Dict, List, Any

def handler(event: Dict[str, Any], context: Any) -> Dict[str, Any]:
    """
    Cost optimization Lambda function for social media platform.
    
    Analyzes costs and provides optimization recommendations.
    """
    
    # Initialize AWS clients
    ce_client = boto3.client('ce')  # Cost Explorer
    ec2_client = boto3.client('ec2')
    ecs_client = boto3.client('ecs')
    rds_client = boto3.client('rds')
    sns_client = boto3.client('sns')
    
    # Environment variables
    project_name = os.environ.get('PROJECT_NAME', '${project_name}')
    environment = os.environ.get('ENVIRONMENT', 'development')
    sns_topic_arn = os.environ.get('SNS_TOPIC_ARN')
    slack_webhook_url = os.environ.get('SLACK_WEBHOOK_URL')
    
    try:
        # Collect cost data
        cost_data = collect_cost_data(ce_client, project_name)
        
        # Analyze resource utilization
        utilization_data = analyze_resource_utilization(ec2_client, ecs_client, rds_client)
        
        # Generate recommendations
        recommendations = generate_recommendations(cost_data, utilization_data)
        
        # Send notifications
        if recommendations:
            send_notifications(sns_client, sns_topic_arn, recommendations, slack_webhook_url)
        
        return {
            'statusCode': 200,
            'body': json.dumps({
                'cost_data': cost_data,
                'utilization_data': utilization_data,
                'recommendations': recommendations,
                'timestamp': datetime.utcnow().isoformat()
            })
        }
        
    except Exception as e:
        print(f"Error in cost optimization: {str(e)}")
        return {
            'statusCode': 500,
            'body': json.dumps({'error': str(e)})
        }

def collect_cost_data(ce_client, project_name: str) -> Dict[str, Any]:
    """Collect cost data from Cost Explorer"""
    
    # Get last 30 days of cost data
    end_date = datetime.utcnow().date()
    start_date = end_date - timedelta(days=30)
    
    try:
        response = ce_client.get_cost_and_usage(
            TimePeriod={
                'Start': start_date.strftime('%Y-%m-%d'),
                'End': end_date.strftime('%Y-%m-%d')
            },
            Granularity='DAILY',
            Metrics=['BlendedCost'],
            GroupBy=[
                {'Type': 'DIMENSION', 'Key': 'SERVICE'},
                {'Type': 'TAG', 'Key': 'Project'}
            ],
            Filter={
                'Tags': {
                    'Key': 'Project',
                    'Values': [project_name]
                }
            }
        )
        
        # Process cost data
        total_cost = 0
        service_costs = {}
        
        for result in response.get('ResultsByTime', []):
            for group in result.get('Groups', []):
                cost = float(group['Metrics']['BlendedCost']['Amount'])
                service = group['Keys'][0]
                
                total_cost += cost
                service_costs[service] = service_costs.get(service, 0) + cost
        
        return {
            'total_cost_30_days': total_cost,
            'service_breakdown': service_costs,
            'daily_costs': response.get('ResultsByTime', [])
        }
        
    except Exception as e:
        print(f"Error collecting cost data: {str(e)}")
        return {'error': str(e)}

def analyze_resource_utilization(ec2_client, ecs_client, rds_client) -> Dict[str, Any]:
    """Analyze resource utilization"""
    
    utilization = {
        'ec2_instances': [],
        'ecs_services': [],
        'rds_instances': []
    }
    
    try:
        # Analyze EC2 instances
        ec2_response = ec2_client.describe_instances()
        for reservation in ec2_response['Reservations']:
            for instance in reservation['Instances']:
                if instance['State']['Name'] == 'running':
                    utilization['ec2_instances'].append({
                        'instance_id': instance['InstanceId'],
                        'instance_type': instance['InstanceType'],
                        'launch_time': instance['LaunchTime'].isoformat(),
                        'state': instance['State']['Name']
                    })
        
        # Analyze ECS services
        clusters_response = ecs_client.list_clusters()
        for cluster_arn in clusters_response['clusterArns']:
            services_response = ecs_client.list_services(cluster=cluster_arn)
            
            if services_response['serviceArns']:
                services_detail = ecs_client.describe_services(
                    cluster=cluster_arn,
                    services=services_response['serviceArns']
                )
                
                for service in services_detail['services']:
                    utilization['ecs_services'].append({
                        'service_name': service['serviceName'],
                        'cluster_name': cluster_arn.split('/')[-1],
                        'running_count': service['runningCount'],
                        'desired_count': service['desiredCount'],
                        'task_definition': service['taskDefinition']
                    })
        
        # Analyze RDS instances
        rds_response = rds_client.describe_db_instances()
        for instance in rds_response['DBInstances']:
            utilization['rds_instances'].append({
                'db_instance_id': instance['DBInstanceIdentifier'],
                'db_instance_class': instance['DBInstanceClass'],
                'engine': instance['Engine'],
                'status': instance['DBInstanceStatus'],
                'allocated_storage': instance.get('AllocatedStorage', 0)
            })
            
    except Exception as e:
        print(f"Error analyzing utilization: {str(e)}")
        utilization['error'] = str(e)
    
    return utilization

def generate_recommendations(cost_data: Dict[str, Any], utilization_data: Dict[str, Any]) -> List[Dict[str, Any]]:
    """Generate cost optimization recommendations"""
    
    recommendations = []
    
    # Cost-based recommendations
    if 'service_breakdown' in cost_data:
        service_costs = cost_data['service_breakdown']
        
        # Check for high EC2 costs
        ec2_cost = service_costs.get('Amazon Elastic Compute Cloud - Compute', 0)
        if ec2_cost > 1000:  # $1000 threshold
            recommendations.append({
                'type': 'cost_optimization',
                'service': 'EC2',
                'severity': 'medium',
                'title': 'High EC2 Costs Detected',
                'description': f'EC2 costs are ${ec2_cost:.2f} in the last 30 days',
                'actions': [
                    'Consider using Spot Instances for non-critical workloads',
                    'Right-size instances based on utilization',
                    'Use Reserved Instances for predictable workloads'
                ]
            })
        
        # Check for high RDS costs
        rds_cost = service_costs.get('Amazon Relational Database Service', 0)
        if rds_cost > 500:  # $500 threshold
            recommendations.append({
                'type': 'cost_optimization',
                'service': 'RDS',
                'severity': 'medium',
                'title': 'High RDS Costs Detected',
                'description': f'RDS costs are ${rds_cost:.2f} in the last 30 days',
                'actions': [
                    'Consider Aurora Serverless for variable workloads',
                    'Use read replicas to distribute load',
                    'Implement database connection pooling'
                ]
            })
    
    # Utilization-based recommendations
    if 'ecs_services' in utilization_data:
        for service in utilization_data['ecs_services']:
            if service['running_count'] != service['desired_count']:
                recommendations.append({
                    'type': 'resource_optimization',
                    'service': 'ECS',
                    'severity': 'low',
                    'title': f'ECS Service Scaling Issue: {service["service_name"]}',
                    'description': f'Running: {service["running_count"]}, Desired: {service["desired_count"]}',
                    'actions': [
                        'Check service health and auto-scaling policies',
                        'Review task resource requirements'
                    ]
                })
    
    # General recommendations
    recommendations.append({
        'type': 'general',
        'service': 'All',
        'severity': 'low',
        'title': 'Regular Cost Review',
        'description': 'Implement regular cost review processes',
        'actions': [
            'Set up billing alerts',
            'Use AWS Cost Explorer regularly',
            'Implement resource tagging strategy',
            'Consider AWS Savings Plans'
        ]
    })
    
    return recommendations

def send_notifications(sns_client, sns_topic_arn: str, recommendations: List[Dict], slack_webhook_url: str):
    """Send cost optimization notifications"""
    
    if not recommendations:
        return
    
    # Create summary message
    high_severity = len([r for r in recommendations if r.get('severity') == 'high'])
    medium_severity = len([r for r in recommendations if r.get('severity') == 'medium'])
    low_severity = len([r for r in recommendations if r.get('severity') == 'low'])
    
    message = f"""
Cost Optimization Report - {datetime.utcnow().strftime('%Y-%m-%d')}

Summary:
- High Priority: {high_severity} recommendations
- Medium Priority: {medium_severity} recommendations  
- Low Priority: {low_severity} recommendations

Top Recommendations:
"""
    
    for i, rec in enumerate(recommendations[:3], 1):
        message += f"\n{i}. {rec['title']} ({rec['severity'].upper()})"
        message += f"\n   {rec['description']}"
    
    # Send SNS notification
    if sns_topic_arn:
        try:
            sns_client.publish(
                TopicArn=sns_topic_arn,
                Subject='Cost Optimization Report',
                Message=message
            )
            print("SNS notification sent successfully")
        except Exception as e:
            print(f"Error sending SNS notification: {str(e)}")
    
    # Send Slack notification (if webhook URL provided)
    if slack_webhook_url:
        try:
            import urllib.request
            import urllib.parse
            
            slack_message = {
                "text": "Cost Optimization Report",
                "attachments": [
                    {
                        "color": "warning" if high_severity > 0 else "good",
                        "fields": [
                            {
                                "title": "Summary",
                                "value": f"High: {high_severity}, Medium: {medium_severity}, Low: {low_severity}",
                                "short": True
                            }
                        ]
                    }
                ]
            }
            
            data = urllib.parse.urlencode({"payload": json.dumps(slack_message)}).encode()
            req = urllib.request.Request(slack_webhook_url, data=data)
            urllib.request.urlopen(req)
            print("Slack notification sent successfully")
            
        except Exception as e:
            print(f"Error sending Slack notification: {str(e)}")

if __name__ == "__main__":
    # For local testing
    test_event = {}
    test_context = {}
    result = handler(test_event, test_context)
    print(json.dumps(result, indent=2))