output "compliance_api_endpoint" {
  description = "Compliance API Gateway endpoint URL"
  value       = aws_apigatewayv2_stage.compliance_api.invoke_url
}

output "compliance_api_id" {
  description = "Compliance API Gateway ID"
  value       = aws_apigatewayv2_api.compliance_api.id
}

output "data_rights_processor_function_arn" {
  description = "Data rights processor Lambda function ARN"
  value       = aws_lambda_function.data_rights_processor.arn
}

output "data_retention_processor_function_arn" {
  description = "Data retention processor Lambda function ARN"
  value       = aws_lambda_function.data_retention_processor.arn
}

output "compliance_notifications_topic_arn" {
  description = "Compliance notifications SNS topic ARN"
  value       = aws_sns_topic.compliance_notifications.arn
}

output "user_consent_table_name" {
  description = "User consent DynamoDB table name"
  value       = aws_dynamodb_table.user_consent.name
}

output "data_subject_requests_table_name" {
  description = "Data subject requests DynamoDB table name"
  value       = aws_dynamodb_table.data_subject_requests.name
}

output "audit_log_table_name" {
  description = "Audit log DynamoDB table name"
  value       = aws_dynamodb_table.audit_log.name
}

output "compliance_encryption_key_id" {
  description = "Compliance encryption KMS key ID"
  value       = aws_kms_key.compliance_encryption.key_id
}

output "compliance_encryption_key_arn" {
  description = "Compliance encryption KMS key ARN"
  value       = aws_kms_key.compliance_encryption.arn
}

output "data_subject_requests_queue_url" {
  description = "Data subject requests SQS queue URL"
  value       = aws_sqs_queue.data_subject_requests.url
}

output "data_subject_requests_queue_arn" {
  description = "Data subject requests SQS queue ARN"
  value       = aws_sqs_queue.data_subject_requests.arn
}

output "macie_account_id" {
  description = "Macie account ID"
  value       = aws_macie2_account.main.id
}

output "data_classification_job_id" {
  description = "Macie data classification job ID"
  value       = aws_macie2_classification_job.data_discovery.job_id
}

output "glue_anonymization_job_name" {
  description = "Glue data anonymization job name"
  value       = aws_glue_job.data_anonymization.name
}

output "compliance_lambda_security_group_id" {
  description = "Security group ID for compliance Lambda functions"
  value       = aws_security_group.compliance_lambda.id
}