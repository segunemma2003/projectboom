output "message_processing_queue_arn" {
  description = "SQS queue ARN for message processing"
  value       = aws_sqs_queue.message_processing.arn
}

output "group_chat_queue_arn" {
  description = "FIFO SQS queue ARN for group chat"
  value       = aws_sqs_queue.group_chat_fifo.arn
}

output "chat_notifications_topic_arn" {
  description = "SNS topic ARN for chat notifications"
  value       = aws_sns_topic.chat_notifications.arn
}

output "group_notifications_topic_arn" {
  description = "FIFO SNS topic ARN for group notifications"
  value       = aws_sns_topic.group_chat_notifications.arn
}

output "chat_messages_table_name" {
  description = "DynamoDB table name for chat messages"
  value       = var.use_customer_managed_kms ? aws_dynamodb_table.chat_messages_with_kms[0].name : aws_dynamodb_table.chat_messages.name
}

output "conversations_table_name" {
  description = "DynamoDB table name for conversations"
  value       = aws_dynamodb_table.conversations.name
}

output "user_conversations_table_name" {
  description = "DynamoDB table name for user conversations"
  value       = aws_dynamodb_table.user_conversations.name
}

output "user_presence_table_name" {
  description = "DynamoDB table name for user presence"
  value       = aws_dynamodb_table.user_presence.name
}

output "kms_key_id" {
  description = "KMS key ID for chat encryption"
  value       = aws_kms_key.chat_encryption.key_id
}

output "kms_key_arn" {
  description = "KMS key ARN for chat encryption"
  value       = aws_kms_key.chat_encryption.arn
}

output "message_processor_function_name" {
  description = "Lambda function name for message processing"
  value       = aws_lambda_function.message_processor.function_name
}

output "presence_manager_function_name" {
  description = "Lambda function name for presence management"
  value       = aws_lambda_function.presence_manager.function_name
}