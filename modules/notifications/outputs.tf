output "push_notifications_topic_arn" {
  description = "SNS topic ARN for push notifications"
  value       = aws_sns_topic.push_notifications.arn
}

output "email_notifications_topic_arn" {
  description = "SNS topic ARN for email notifications"
  value       = aws_sns_topic.email_notifications.arn
}

output "sms_notifications_topic_arn" {
  description = "SNS topic ARN for SMS notifications"
  value       = aws_sns_topic.sms_notifications.arn
}

output "in_app_notifications_topic_arn" {
  description = "SNS topic ARN for in-app notifications"
  value       = aws_sns_topic.in_app_notifications.arn
}

output "notification_preferences_table_name" {
  description = "DynamoDB table name for notification preferences"
  value       = aws_dynamodb_table.notification_preferences.name
}

output "notification_preferences_table_arn" {
  description = "DynamoDB table ARN for notification preferences"
  value       = aws_dynamodb_table.notification_preferences.arn
}

output "notification_history_table_name" {
  description = "DynamoDB table name for notification history"
  value       = aws_dynamodb_table.notification_history.name
}

output "notification_history_table_arn" {
  description = "DynamoDB table ARN for notification history"
  value       = aws_dynamodb_table.notification_history.arn
}

output "notification_processing_queue_url" {
  description = "SQS queue URL for notification processing"
  value       = aws_sqs_queue.notification_processing.url
}

output "notification_processing_queue_arn" {
  description = "SQS queue ARN for notification processing"
  value       = aws_sqs_queue.notification_processing.arn
}

output "priority_notifications_queue_url" {
  description = "FIFO SQS queue URL for priority notifications"
  value       = aws_sqs_queue.priority_notifications.url
}

output "priority_notifications_queue_arn" {
  description = "FIFO SQS queue ARN for priority notifications"
  value       = aws_sqs_queue.priority_notifications.arn
}

output "push_processor_function_name" {
  description = "Push processor Lambda function name"
  value       = aws_lambda_function.push_processor.function_name
}

output "push_processor_function_arn" {
  description = "Push processor Lambda function ARN"
  value       = aws_lambda_function.push_processor.arn
}

output "email_processor_function_name" {
  description = "Email processor Lambda function name"
  value       = aws_lambda_function.email_processor.function_name
}

output "email_processor_function_arn" {
  description = "Email processor Lambda function ARN"
  value       = aws_lambda_function.email_processor.arn
}

output "sms_processor_function_name" {
  description = "SMS processor Lambda function name"
  value       = aws_lambda_function.sms_processor.function_name
}

output "sms_processor_function_arn" {
  description = "SMS processor Lambda function ARN"
  value       = aws_lambda_function.sms_processor.arn
}

output "in_app_processor_function_name" {
  description = "In-app processor Lambda function name"
  value       = aws_lambda_function.in_app_processor.function_name
}

output "in_app_processor_function_arn" {
  description = "In-app processor Lambda function ARN"
  value       = aws_lambda_function.in_app_processor.arn
}

output "notification_scheduler_function_name" {
  description = "Notification scheduler Lambda function name"
  value       = aws_lambda_function.notification_scheduler.function_name
}

output "notification_scheduler_function_arn" {
  description = "Notification scheduler Lambda function ARN"
  value       = aws_lambda_function.notification_scheduler.arn
}

output "notification_api_function_name" {
  description = "Notification API Lambda function name"
  value       = aws_lambda_function.notification_api.function_name
}

output "notification_api_function_arn" {
  description = "Notification API Lambda function ARN"
  value       = aws_lambda_function.notification_api.arn
}

output "notification_api_endpoint" {
  description = "Notification API Gateway endpoint URL"
  value       = aws_apigatewayv2_stage.notification_api.invoke_url
}

output "notification_api_id" {
  description = "Notification API Gateway ID"
  value       = aws_apigatewayv2_api.notification_api.id
}

output "email_templates_bucket_name" {
  description = "S3 bucket name for email templates"
  value       = aws_s3_bucket.email_templates.bucket
}

output "email_templates_bucket_arn" {
  description = "S3 bucket ARN for email templates"
  value       = aws_s3_bucket.email_templates.arn
}

output "notification_lambda_role_arn" {
  description = "IAM role ARN for notification Lambda functions"
  value       = aws_iam_role.notification_lambda.arn
}

output "notification_lambda_role_name" {
  description = "IAM role name for notification Lambda functions"
  value       = aws_iam_role.notification_lambda.name
}

# CloudWatch alarm outputs
output "notification_errors_alarm_arn" {
  description = "CloudWatch alarm ARN for notification errors"
  value       = aws_cloudwatch_metric_alarm.notification_errors.arn
}

output "notification_queue_depth_alarm_arn" {
  description = "CloudWatch alarm ARN for notification queue depth"
  value       = aws_cloudwatch_metric_alarm.notification_queue_depth.arn
}

# EventBridge rule outputs
output "notification_scheduler_rule_arn" {
  description = "EventBridge rule ARN for notification scheduler"
  value       = aws_cloudwatch_event_rule.notification_scheduler.arn
}