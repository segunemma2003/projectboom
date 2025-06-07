# OpenSearch Outputs
output "opensearch_domain_arn" {
  description = "ARN of the OpenSearch domain"
  value       = aws_opensearch_domain.main.arn
}

output "opensearch_domain_id" {
  description = "Unique identifier for the OpenSearch domain"
  value       = aws_opensearch_domain.main.domain_id
}

output "opensearch_domain_name" {
  description = "Name of the OpenSearch domain"
  value       = aws_opensearch_domain.main.domain_name
}

output "opensearch_endpoint" {
  description = "Domain-specific endpoint used to submit index, search, and data upload requests"
  value       = aws_opensearch_domain.main.endpoint
}

output "opensearch_dashboard_endpoint" {
  description = "Domain-specific endpoint for OpenSearch Dashboards"
  value       = aws_opensearch_domain.main.dashboard_endpoint
}

output "opensearch_security_group_id" {
  description = "ID of the security group for OpenSearch"
  value       = aws_security_group.opensearch.id
}

# DynamoDB Outputs
output "search_metadata_table_name" {
  description = "Name of the DynamoDB table for search index metadata"
  value       = aws_dynamodb_table.search_index_metadata.name
}

output "search_metadata_table_arn" {
  description = "ARN of the DynamoDB table for search index metadata"
  value       = aws_dynamodb_table.search_index_metadata.arn
}

# SQS Outputs
output "search_indexing_queue_url" {
  description = "URL of the SQS queue for search indexing jobs"
  value       = aws_sqs_queue.search_indexing.url
}

output "search_indexing_queue_arn" {
  description = "ARN of the SQS queue for search indexing jobs"
  value       = aws_sqs_queue.search_indexing.arn
}

output "search_indexing_dlq_url" {
  description = "URL of the SQS dead letter queue for search indexing"
  value       = aws_sqs_queue.search_indexing_dlq.url
}

output "search_indexing_dlq_arn" {
  description = "ARN of the SQS dead letter queue for search indexing"
  value       = aws_sqs_queue.search_indexing_dlq.arn
}

# Lambda Outputs
output "search_indexer_function_name" {
  description = "Name of the search indexer Lambda function"
  value       = aws_lambda_function.search_indexer.function_name
}

output "search_indexer_function_arn" {
  description = "ARN of the search indexer Lambda function"
  value       = aws_lambda_function.search_indexer.arn
}

output "search_indexer_invoke_arn" {
  description = "Invoke ARN of the search indexer Lambda function"
  value       = aws_lambda_function.search_indexer.invoke_arn
}

output "search_api_function_name" {
  description = "Name of the search API Lambda function"
  value       = aws_lambda_function.search_api.function_name
}

output "search_api_function_arn" {
  description = "ARN of the search API Lambda function"
  value       = aws_lambda_function.search_api.arn
}

output "search_api_invoke_arn" {
  description = "Invoke ARN of the search API Lambda function"
  value       = aws_lambda_function.search_api.invoke_arn
}

output "search_lambda_security_group_id" {
  description = "ID of the security group for search Lambda functions"
  value       = aws_security_group.search_lambda.id
}

output "search_lambda_role_arn" {
  description = "ARN of the IAM role for search Lambda functions"
  value       = aws_iam_role.search_lambda.arn
}

output "search_lambda_role_name" {
  description = "Name of the IAM role for search Lambda functions"
  value       = aws_iam_role.search_lambda.name
}

# API Gateway Outputs
output "search_api_gateway_id" {
  description = "ID of the API Gateway for search API"
  value       = aws_apigatewayv2_api.search_api.id
}

output "search_api_gateway_arn" {
  description = "ARN of the API Gateway for search API"
  value       = aws_apigatewayv2_api.search_api.arn
}

output "search_api_gateway_execution_arn" {
  description = "Execution ARN of the API Gateway for search API"
  value       = aws_apigatewayv2_api.search_api.execution_arn
}

output "search_api_endpoint" {
  description = "API Gateway endpoint URL for search API"
  value       = "${aws_apigatewayv2_api.search_api.api_endpoint}/${aws_apigatewayv2_stage.search_api.name}"
}

output "search_api_stage_name" {
  description = "Name of the API Gateway stage"
  value       = aws_apigatewayv2_stage.search_api.name
}

# CloudWatch Outputs
output "opensearch_log_groups" {
  description = "CloudWatch log groups for OpenSearch"
  value = {
    index_slow     = aws_cloudwatch_log_group.opensearch_index_slow.name
    search_slow    = aws_cloudwatch_log_group.opensearch_search_slow.name
    es_application = aws_cloudwatch_log_group.opensearch_es_application.name
  }
}

output "search_api_log_group_name" {
  description = "Name of the CloudWatch log group for search API"
  value       = aws_cloudwatch_log_group.search_api.name
}

output "search_api_log_group_arn" {
  description = "ARN of the CloudWatch log group for search API"
  value       = aws_cloudwatch_log_group.search_api.arn
}

# Monitoring Outputs
output "cloudwatch_alarms" {
  description = "CloudWatch alarms for monitoring"
  value = {
    opensearch_cluster_status = aws_cloudwatch_metric_alarm.opensearch_cluster_status.arn
    opensearch_cpu_high      = aws_cloudwatch_metric_alarm.opensearch_cpu_utilization.arn
    search_indexing_errors   = aws_cloudwatch_metric_alarm.search_indexing_errors.arn
  }
}

# Configuration Outputs
output "search_configuration" {
  description = "Search service configuration values"
  value = {
    opensearch_endpoint     = aws_opensearch_domain.main.endpoint
    metadata_table_name     = aws_dynamodb_table.search_index_metadata.name
    indexing_queue_url      = aws_sqs_queue.search_indexing.url
    api_endpoint           = "${aws_apigatewayv2_api.search_api.api_endpoint}/${aws_apigatewayv2_stage.search_api.name}"
    indexer_function_name  = aws_lambda_function.search_indexer.function_name
    api_function_name      = aws_lambda_function.search_api.function_name
  }
  sensitive = false
}

# Resource Identifiers for External Integration
output "resource_identifiers" {
  description = "Resource identifiers for external integration"
  value = {
    opensearch_domain_name          = aws_opensearch_domain.main.domain_name
    search_metadata_table_name      = aws_dynamodb_table.search_index_metadata.name
    search_indexing_queue_name      = aws_sqs_queue.search_indexing.name
    search_indexer_function_name    = aws_lambda_function.search_indexer.function_name
    search_api_function_name        = aws_lambda_function.search_api.function_name
    search_api_gateway_name         = aws_apigatewayv2_api.search_api.name
    opensearch_security_group_id    = aws_security_group.opensearch.id
    lambda_security_group_id        = aws_security_group.search_lambda.id
    lambda_role_name               = aws_iam_role.search_lambda.name
  }
}