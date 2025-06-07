# modules/media_processing/main.tf - Media processing for social media platform
terraform {
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
  }
}

# S3 bucket for raw media uploads
resource "aws_s3_bucket" "raw_media" {
  bucket = "${var.name_prefix}-raw-media-${random_id.bucket_suffix.hex}"
  tags   = var.tags
}

resource "random_id" "bucket_suffix" {
  byte_length = 4
}

# S3 bucket for processed media
resource "aws_s3_bucket" "processed_media" {
  bucket = "${var.name_prefix}-processed-media-${random_id.bucket_suffix.hex}"
  tags   = var.tags
}

# S3 bucket for thumbnails
resource "aws_s3_bucket" "thumbnails" {
  bucket = "${var.name_prefix}-thumbnails-${random_id.bucket_suffix.hex}"
  tags   = var.tags
}

# Lifecycle configuration for raw media (delete after processing)
resource "aws_s3_bucket_lifecycle_configuration" "raw_media" {
  bucket = aws_s3_bucket.raw_media.id

  rule {
    id     = "delete_raw_after_processing"
    status = "Enabled"

    expiration {
      days = var.raw_media_retention_days
    }

    noncurrent_version_expiration {
      noncurrent_days = 1
    }
  }
}

# Lifecycle configuration for processed media
resource "aws_s3_bucket_lifecycle_configuration" "processed_media" {
  bucket = aws_s3_bucket.processed_media.id

  rule {
    id     = "processed_media_lifecycle"
    status = "Enabled"

    transition {
      days          = 30
      storage_class = "STANDARD_IA"
    }

    transition {
      days          = 90
      storage_class = "GLACIER"
    }

    transition {
      days          = 365
      storage_class = "DEEP_ARCHIVE"
    }
  }
}

# CORS configuration for media buckets
resource "aws_s3_bucket_cors_configuration" "raw_media" {
  bucket = aws_s3_bucket.raw_media.id

  cors_rule {
    allowed_headers = ["*"]
    allowed_methods = ["GET", "POST", "PUT", "DELETE", "HEAD"]
    allowed_origins = ["https://${var.domain_name}", "https://www.${var.domain_name}"]
    expose_headers  = ["ETag", "Content-Length"]
    max_age_seconds = 3000
  }
}

resource "aws_s3_bucket_cors_configuration" "processed_media" {
  bucket = aws_s3_bucket.processed_media.id

  cors_rule {
    allowed_headers = ["Authorization", "Content-Length"]
    allowed_methods = ["GET", "HEAD"]
    allowed_origins = ["*"]
    expose_headers  = ["ETag"]
    max_age_seconds = 86400
  }
}

# SQS queue for media processing jobs
resource "aws_sqs_queue" "media_processing" {
  name                      = "${var.name_prefix}-media-processing"
  delay_seconds             = 0
  max_message_size          = 262144
  message_retention_seconds = 1209600
  receive_wait_time_seconds = 20

  redrive_policy = jsonencode({
    deadLetterTargetArn = aws_sqs_queue.media_processing_dlq.arn
    maxReceiveCount     = 3
  })

  tags = var.tags
}

resource "aws_sqs_queue" "media_processing_dlq" {
  name = "${var.name_prefix}-media-processing-dlq"
  tags = var.tags
}

# SNS topic for processing notifications
resource "aws_sns_topic" "media_processing_notifications" {
  name = "${var.name_prefix}-media-processing-notifications"
  tags = var.tags
}

# Lambda function for image processing
resource "aws_lambda_function" "image_processor" {
  filename         = data.archive_file.image_processor.output_path
  function_name    = "${var.name_prefix}-image-processor"
  role            = aws_iam_role.media_processing_lambda.arn
  handler         = "image_processor.handler"
  source_code_hash = data.archive_file.image_processor.output_base64sha256
  runtime         = "python3.11"
  timeout         = 300
  memory_size     = 1024

  environment {
    variables = {
      PROCESSED_BUCKET   = aws_s3_bucket.processed_media.bucket
      THUMBNAILS_BUCKET  = aws_s3_bucket.thumbnails.bucket
      SNS_TOPIC_ARN     = aws_sns_topic.media_processing_notifications.arn
      MAX_IMAGE_SIZE    = var.max_image_size
      THUMBNAIL_SIZES   = jsonencode(var.thumbnail_sizes)
      ALLOWED_FORMATS   = jsonencode(var.allowed_image_formats)
    }
  }

  reserved_concurrent_executions = var.lambda_concurrent_executions

  tags = var.tags
}

# Lambda function for video processing
resource "aws_lambda_function" "video_processor" {
  filename         = data.archive_file.video_processor.output_path
  function_name    = "${var.name_prefix}-video-processor"
  role            = aws_iam_role.media_processing_lambda.arn
  handler         = "video_processor.handler"
  source_code_hash = data.archive_file.video_processor.output_base64sha256
  runtime         = "python3.11"
  timeout         = 900
  memory_size     = 3008

  environment {
    variables = {
      PROCESSED_BUCKET     = aws_s3_bucket.processed_media.bucket
      THUMBNAILS_BUCKET    = aws_s3_bucket.thumbnails.bucket
      SNS_TOPIC_ARN       = aws_sns_topic.media_processing_notifications.arn
      MEDIACONVERT_ROLE   = aws_iam_role.mediaconvert.arn
      MEDIACONVERT_QUEUE  = aws_media_convert_queue.main.name
      MAX_VIDEO_SIZE      = var.max_video_size
      VIDEO_FORMATS       = jsonencode(var.video_output_formats)
      ALLOWED_FORMATS     = jsonencode(var.allowed_video_formats)
    }
  }

  reserved_concurrent_executions = var.lambda_concurrent_executions

  tags = var.tags
}

# S3 event notifications for automatic processing
resource "aws_s3_bucket_notification" "raw_media_notification" {
  bucket = aws_s3_bucket.raw_media.id

  lambda_function {
    lambda_function_arn = aws_lambda_function.image_processor.arn
    events              = ["s3:ObjectCreated:*"]
    filter_prefix       = "images/"
    filter_suffix       = ""
  }

  lambda_function {
    lambda_function_arn = aws_lambda_function.video_processor.arn
    events              = ["s3:ObjectCreated:*"]
    filter_prefix       = "videos/"
    filter_suffix       = ""
  }

  depends_on = [
    aws_lambda_permission.s3_invoke_image_processor,
    aws_lambda_permission.s3_invoke_video_processor
  ]
}

# Lambda permissions for S3 triggers
resource "aws_lambda_permission" "s3_invoke_image_processor" {
  statement_id  = "AllowExecutionFromS3Bucket"
  action        = "lambda:InvokeFunction"
  function_name = aws_lambda_function.image_processor.function_name
  principal     = "s3.amazonaws.com"
  source_arn    = aws_s3_bucket.raw_media.arn
}

resource "aws_lambda_permission" "s3_invoke_video_processor" {
  statement_id  = "AllowExecutionFromS3Bucket"
  action        = "lambda:InvokeFunction"
  function_name = aws_lambda_function.video_processor.function_name
  principal     = "s3.amazonaws.com"
  source_arn    = aws_s3_bucket.raw_media.arn
}

# MediaConvert queue for video processing
resource "aws_media_convert_queue" "main" {
  name = "${var.name_prefix}-video-processing"

  pricing_plan = var.mediaconvert_pricing_plan
  
  reservation_plan_settings {
    commitment          = var.mediaconvert_commitment
    renewal_type       = "AUTO_RENEW"
    reserved_slots     = var.mediaconvert_reserved_slots
  }

  tags = var.tags
}

# IAM role for MediaConvert
resource "aws_iam_role" "mediaconvert" {
  name = "${var.name_prefix}-mediaconvert-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action = "sts:AssumeRole"
        Effect = "Allow"
        Principal = {
          Service = "mediaconvert.amazonaws.com"
        }
      }
    ]
  })

  tags = var.tags
}

resource "aws_iam_role_policy" "mediaconvert" {
  name = "${var.name_prefix}-mediaconvert-policy"
  role = aws_iam_role.mediaconvert.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Action = [
          "s3:GetObject",
          "s3:PutObject",
          "s3:GetObjectVersion"
        ]
        Resource = [
          "${aws_s3_bucket.raw_media.arn}/*",
          "${aws_s3_bucket.processed_media.arn}/*",
          "${aws_s3_bucket.thumbnails.arn}/*"
        ]
      },
      {
        Effect = "Allow"
        Action = [
          "s3:ListBucket"
        ]
        Resource = [
          aws_s3_bucket.raw_media.arn,
          aws_s3_bucket.processed_media.arn,
          aws_s3_bucket.thumbnails.arn
        ]
      }
    ]
  })
}

# IAM role for Lambda functions
resource "aws_iam_role" "media_processing_lambda" {
  name = "${var.name_prefix}-media-processing-lambda-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action = "sts:AssumeRole"
        Effect = "Allow"
        Principal = {
          Service = "lambda.amazonaws.com"
        }
      }
    ]
  })

  tags = var.tags
}

resource "aws_iam_role_policy" "media_processing_lambda" {
  name = "${var.name_prefix}-media-processing-lambda-policy"
  role = aws_iam_role.media_processing_lambda.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Action = [
          "s3:GetObject",
          "s3:PutObject",
          "s3:DeleteObject",
          "s3:GetObjectVersion"
        ]
        Resource = [
          "${aws_s3_bucket.raw_media.arn}/*",
          "${aws_s3_bucket.processed_media.arn}/*",
          "${aws_s3_bucket.thumbnails.arn}/*"
        ]
      },
      {
        Effect = "Allow"
        Action = [
          "s3:ListBucket"
        ]
        Resource = [
          aws_s3_bucket.raw_media.arn,
          aws_s3_bucket.processed_media.arn,
          aws_s3_bucket.thumbnails.arn
        ]
      },
      {
        Effect = "Allow"
        Action = [
          "sns:Publish"
        ]
        Resource = aws_sns_topic.media_processing_notifications.arn
      },
      {
        Effect = "Allow"
        Action = [
          "mediaconvert:CreateJob",
          "mediaconvert:GetJob",
          "mediaconvert:ListJobs",
          "mediaconvert:DescribeEndpoints"
        ]
        Resource = "*"
      },
      {
        Effect = "Allow"
        Action = [
          "iam:PassRole"
        ]
        Resource = aws_iam_role.mediaconvert.arn
      },
      {
        Effect = "Allow"
        Action = [
          "sqs:SendMessage",
          "sqs:ReceiveMessage",
          "sqs:DeleteMessage",
          "sqs:GetQueueAttributes"
        ]
        Resource = [
          aws_sqs_queue.media_processing.arn,
          aws_sqs_queue.media_processing_dlq.arn
        ]
      }
    ]
  })
}

resource "aws_iam_role_policy_attachment" "lambda_basic_execution" {
  role       = aws_iam_role.media_processing_lambda.name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AWSLambdaBasicExecutionRole"
}

# CloudWatch alarms for monitoring
resource "aws_cloudwatch_metric_alarm" "lambda_errors" {
  alarm_name          = "${var.name_prefix}-media-processing-errors"
  comparison_operator = "GreaterThanThreshold"
  evaluation_periods  = "2"
  metric_name         = "Errors"
  namespace           = "AWS/Lambda"
  period              = "300"
  statistic           = "Sum"
  threshold           = "5"
  alarm_description   = "Media processing Lambda function errors"
  alarm_actions       = var.alarm_actions

  dimensions = {
    FunctionName = aws_lambda_function.image_processor.function_name
  }

  tags = var.tags
}

resource "aws_cloudwatch_metric_alarm" "processing_queue_depth" {
  alarm_name          = "${var.name_prefix}-media-processing-queue-depth"
  comparison_operator = "GreaterThanThreshold"
  evaluation_periods  = "2"
  metric_name         = "ApproximateNumberOfMessages"
  namespace           = "AWS/SQS"
  period              = "300"
  statistic           = "Average"
  threshold           = "100"
  alarm_description   = "High number of messages in media processing queue"
  alarm_actions       = var.alarm_actions

  dimensions = {
    QueueName = aws_sqs_queue.media_processing.name
  }

  tags = var.tags
}

# Lambda packages (placeholders for actual code)
data "archive_file" "image_processor" {
  type        = "zip"
  output_path = "/tmp/image_processor.zip"
  source {
    content = templatefile("${path.module}/lambda/image_processor.py", {
      processed_bucket  = ""
      thumbnails_bucket = ""
    })
    filename = "image_processor.py"
  }
}

data "archive_file" "video_processor" {
  type        = "zip"
  output_path = "/tmp/video_processor.zip"
  source {
    content = templatefile("${path.module}/lambda/video_processor.py", {
      processed_bucket = ""
      mediaconvert_role = ""
    })
    filename = "video_processor.py"
  }
}

# API Gateway for direct uploads (optional)
resource "aws_apigatewayv2_api" "media_upload" {
  count = var.enable_direct_upload_api ? 1 : 0
  
  name          = "${var.name_prefix}-media-upload"
  protocol_type = "HTTP"
  description   = "Media upload API"

  cors_configuration {
    allow_credentials = true
    allow_headers     = ["content-type", "authorization", "x-amz-date", "x-api-key"]
    allow_methods     = ["POST", "OPTIONS"]
    allow_origins     = ["https://${var.domain_name}"]
    max_age          = 300
  }

  tags = var.tags
}

# Content moderation integration
resource "aws_lambda_function" "content_moderator" {
  count = var.enable_content_moderation ? 1 : 0
  
  filename         = data.archive_file.content_moderator[0].output_path
  function_name    = "${var.name_prefix}-content-moderator"
  role            = aws_iam_role.content_moderation_lambda[0].arn
  handler         = "content_moderator.handler"
  source_code_hash = data.archive_file.content_moderator[0].output_base64sha256
  runtime         = "python3.11"
  timeout         = 300
  memory_size     = 1024

  environment {
    variables = {
      REKOGNITION_MIN_CONFIDENCE = var.rekognition_min_confidence
      MODERATION_SNS_TOPIC      = aws_sns_topic.media_processing_notifications.arn
      QUARANTINE_BUCKET         = aws_s3_bucket.quarantine[0].bucket
    }
  }

  tags = var.tags
}

# Quarantine bucket for flagged content
resource "aws_s3_bucket" "quarantine" {
  count  = var.enable_content_moderation ? 1 : 0
  bucket = "${var.name_prefix}-quarantine-${random_id.bucket_suffix.hex}"
  tags   = var.tags
}

# IAM role for content moderation
resource "aws_iam_role" "content_moderation_lambda" {
  count = var.enable_content_moderation ? 1 : 0
  name  = "${var.name_prefix}-content-moderation-lambda-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action = "sts:AssumeRole"
        Effect = "Allow"
        Principal = {
          Service = "lambda.amazonaws.com"
        }
      }
    ]
  })

  tags = var.tags
}

resource "aws_iam_role_policy" "content_moderation_lambda" {
  count = var.enable_content_moderation ? 1 : 0
  name  = "${var.name_prefix}-content-moderation-lambda-policy"
  role  = aws_iam_role.content_moderation_lambda[0].id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Action = [
          "rekognition:DetectModerationLabels",
          "rekognition:DetectText",
          "rekognition:DetectFaces"
        ]
        Resource = "*"
      },
      {
        Effect = "Allow"
        Action = [
          "s3:GetObject",
          "s3:PutObject",
          "s3:DeleteObject"
        ]
        Resource = [
          "${aws_s3_bucket.processed_media.arn}/*",
          "${aws_s3_bucket.quarantine[0].arn}/*"
        ]
      },
      {
        Effect = "Allow"
        Action = [
          "sns:Publish"
        ]
        Resource = aws_sns_topic.media_processing_notifications.arn
      }
    ]
  })
}

data "archive_file" "content_moderator" {
  count = var.enable_content_moderation ? 1 : 0
  
  type        = "zip"
  output_path = "/tmp/content_moderator.zip"
  source {
    content  = file("${path.module}/lambda/content_moderator.py")
    filename = "content_moderator.py"
  }
}