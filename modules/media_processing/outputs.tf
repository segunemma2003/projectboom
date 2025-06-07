output "raw_media_bucket_name" {
  description = "Name of the raw media S3 bucket"
  value       = aws_s3_bucket.raw_media.bucket
}

output "raw_media_bucket_arn" {
  description = "ARN of the raw media S3 bucket"
  value       = aws_s3_bucket.raw_media.arn
}

output "processed_media_bucket_name" {
  description = "Name of the processed media S3 bucket"
  value       = aws_s3_bucket.processed_media.bucket
}

output "processed_media_bucket_arn" {
  description = "ARN of the processed media S3 bucket"
  value       = aws_s3_bucket.processed_media.arn
}

output "thumbnails_bucket_name" {
  description = "Name of the thumbnails S3 bucket"
  value       = aws_s3_bucket.thumbnails.bucket
}

output "thumbnails_bucket_arn" {
  description = "ARN of the thumbnails S3 bucket"
  value       = aws_s3_bucket.thumbnails.arn
}

output "quarantine_bucket_name" {
  description = "Name of the quarantine S3 bucket (if content moderation is enabled)"
  value       = var.enable_content_moderation ? aws_s3_bucket.quarantine[0].bucket : null
}

output "quarantine_bucket_arn" {
  description = "ARN of the quarantine S3 bucket (if content moderation is enabled)"
  value       = var.enable_content_moderation ? aws_s3_bucket.quarantine[0].arn : null
}

output "media_processing_queue_url" {
  description = "URL of the SQS queue for media processing jobs"
  value       = aws_sqs_queue.media_processing.url
}

output "media_processing_queue_arn" {
  description = "ARN of the SQS queue for media processing jobs"
  value       = aws_sqs_queue.media_processing.arn
}

output "media_processing_dlq_url" {
  description = "URL of the SQS dead letter queue for media processing"
  value       = aws_sqs_queue.media_processing_dlq.url
}

output "media_processing_dlq_arn" {
  description = "ARN of the SQS dead letter queue for media processing"
  value       = aws_sqs_queue.media_processing_dlq.arn
}

output "media_processing_notifications_topic_arn" {
  description = "ARN of the SNS topic for media processing notifications"
  value       = aws_sns_topic.media_processing_notifications.arn
}

output "image_processor_function_name" {
  description = "Name of the image processor Lambda function"
  value       = aws_lambda_function.image_processor.function_name
}

output "image_processor_function_arn" {
  description = "ARN of the image processor Lambda function"
  value       = aws_lambda_function.image_processor.arn
}

output "video_processor_function_name" {
  description = "Name of the video processor Lambda function"
  value       = aws_lambda_function.video_processor.function_name
}

output "video_processor_function_arn" {
  description = "ARN of the video processor Lambda function"
  value       = aws_lambda_function.video_processor.arn
}

output "content_moderator_function_name" {
  description = "Name of the content moderator Lambda function (if enabled)"
  value       = var.enable_content_moderation ? aws_lambda_function.content_moderator[0].function_name : null
}

output "content_moderator_function_arn" {
  description = "ARN of the content moderator Lambda function (if enabled)"
  value       = var.enable_content_moderation ? aws_lambda_function.content_moderator[0].arn : null
}

output "mediaconvert_queue_name" {
  description = "Name of the MediaConvert queue"
  value       = aws_media_convert_queue.main.name
}

output "mediaconvert_queue_arn" {
  description = "ARN of the MediaConvert queue"
  value       = aws_media_convert_queue.main.arn
}

output "mediaconvert_role_arn" {
  description = "ARN of the MediaConvert IAM role"
  value       = aws_iam_role.mediaconvert.arn
}

output "media_processing_lambda_role_arn" {
  description = "ARN of the media processing Lambda IAM role"
  value       = aws_iam_role.media_processing_lambda.arn
}

output "content_moderation_lambda_role_arn" {
  description = "ARN of the content moderation Lambda IAM role (if enabled)"
  value       = var.enable_content_moderation ? aws_iam_role.content_moderation_lambda[0].arn : null
}

output "upload_api_endpoint" {
  description = "API Gateway endpoint for direct uploads (if enabled)"
  value       = var.enable_direct_upload_api ? aws_apigatewayv2_api.media_upload[0].api_endpoint : null
}

output "upload_api_id" {
  description = "API Gateway ID for direct uploads (if enabled)"
  value       = var.enable_direct_upload_api ? aws_apigatewayv2_api.media_upload[0].id : null
}

# CloudWatch alarm outputs
output "lambda_errors_alarm_arn" {
  description = "ARN of the Lambda errors CloudWatch alarm"
  value       = aws_cloudwatch_metric_alarm.lambda_errors.arn
}

output "processing_queue_depth_alarm_arn" {
  description = "ARN of the processing queue depth CloudWatch alarm"
  value       = aws_cloudwatch_metric_alarm.processing_queue_depth.arn
}

# Processing configuration outputs
output "supported_image_formats" {
  description = "List of supported image formats"
  value       = var.allowed_image_formats
}

output "supported_video_formats" {
  description = "List of supported video formats"
  value       = var.allowed_video_formats
}

output "thumbnail_sizes" {
  description = "Configured thumbnail sizes"
  value       = var.thumbnail_sizes
}

output "video_output_formats" {
  description = "Configured video output formats"
  value       = var.video_output_formats
}

# Security outputs
output "content_moderation_enabled" {
  description = "Whether content moderation is enabled"
  value       = var.enable_content_moderation
}

output "rekognition_confidence_threshold" {
  description = "Rekognition confidence threshold for content moderation"
  value       = var.rekognition_min_confidence
}

# Storage configuration outputs
output "raw_media_retention_days" {
  description = "Retention period for raw media files in days"
  value       = var.raw_media_retention_days
}

output "encryption_enabled" {
  description = "Whether server-side encryption is enabled"
  value       = var.enable_encryption
}

# Cost optimization outputs
output "intelligent_tiering_enabled" {
  description = "Whether S3 Intelligent Tiering is enabled"
  value       = var.enable_intelligent_tiering
}

output "lifecycle_transitions" {
  description = "S3 lifecycle transition configuration"
  value = {
    ia_days           = var.transition_to_ia_days
    glacier_days      = var.transition_to_glacier_days
    deep_archive_days = var.transition_to_deep_archive_days
  }
}