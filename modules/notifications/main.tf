terraform {
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
  }
}

# SNS Topics for different notification types
resource "aws_sns_topic" "push_notifications" {
  name = "${var.name_prefix}-push-notifications"
  
  tags = merge(var.tags, {
    NotificationType = "Push"
  })
}

resource "aws_sns_topic" "email_notifications" {
  name = "${var.name_prefix}-email-notifications"
  
  tags = merge(var.tags, {
    NotificationType = "Email"
  })
}

resource "aws_sns_topic" "sms_notifications" {
  name = "${var.name_prefix}-sms-notifications"
  
  tags = merge(var.tags, {
    NotificationType = "SMS"
  })
}

resource "aws_sns_topic" "in_app_notifications" {
  name = "${var.name_prefix}-in-app-notifications"
  
  tags = merge(var.tags, {
    NotificationType = "InApp"
  })
}

# DynamoDB table for notification preferences
resource "aws_dynamodb_table" "notification_preferences" {
  name           = "${var.name_prefix}-notification-preferences"
  billing_mode   = "PAY_PER_REQUEST"
  hash_key       = "user_id"

  attribute {
    name = "user_id"
    type = "S"
  }

  attribute {
    name = "notification_type"
    type = "S"
  }

  global_secondary_index {
    name            = "NotificationTypeIndex"
    hash_key        = "notification_type"
    projection_type = "ALL"
  }

  ttl {
    attribute_name = "expires_at"
    enabled        = false
  }

  point_in_time_recovery {
    enabled = true
  }

  server_side_encryption {
    enabled = true
  }

  tags = merge(var.tags, {
    Name = "${var.name_prefix}-notification-preferences"
  })
}

# DynamoDB table for notification history/tracking
resource "aws_dynamodb_table" "notification_history" {
  name           = "${var.name_prefix}-notification-history"
  billing_mode   = "PAY_PER_REQUEST"
  hash_key       = "notification_id"
  range_key      = "timestamp"

  attribute {
    name = "notification_id"
    type = "S"
  }

  attribute {
    name = "timestamp"
    type = "S"
  }

  attribute {
    name = "user_id"
    type = "S"
  }

  attribute {
    name = "status"
    type = "S"
  }

  global_secondary_index {
    name            = "UserNotificationsIndex"
    hash_key        = "user_id"
    range_key       = "timestamp"
    projection_type = "ALL"
  }

  global_secondary_index {
    name            = "StatusIndex"
    hash_key        = "status"
    range_key       = "timestamp"
    projection_type = "KEYS_ONLY"
  }

  ttl {
    attribute_name = "expires_at"
    enabled        = true
  }

  point_in_time_recovery {
    enabled = true
  }

  server_side_encryption {
    enabled = true
  }

  tags = merge(var.tags, {
    Name = "${var.name_prefix}-notification-history"
  })
}

# SQS queues for notification processing
resource "aws_sqs_queue" "notification_processing" {
  name                      = "${var.name_prefix}-notification-processing"
  delay_seconds             = 0
  max_message_size          = 262144
  message_retention_seconds = 1209600
  receive_wait_time_seconds = 20

  redrive_policy = jsonencode({
    deadLetterTargetArn = aws_sqs_queue.notification_dlq.arn
    maxReceiveCount     = 3
  })

  tags = var.tags
}

resource "aws_sqs_queue" "notification_dlq" {
  name = "${var.name_prefix}-notification-dlq"
  tags = var.tags
}

# FIFO queue for high-priority notifications
resource "aws_sqs_queue" "priority_notifications" {
  name                        = "${var.name_prefix}-priority-notifications.fifo"
  fifo_queue                  = true
  content_based_deduplication = true
  delay_seconds               = 0
  max_message_size           = 262144
  message_retention_seconds   = 1209600
  receive_wait_time_seconds   = 20

  redrive_policy = jsonencode({
    deadLetterTargetArn = aws_sqs_queue.priority_dlq.arn
    maxReceiveCount     = 2
  })

  tags = var.tags
}

resource "aws_sqs_queue" "priority_dlq" {
  name       = "${var.name_prefix}-priority-dlq.fifo"
  fifo_queue = true
  tags       = var.tags
}

# Lambda function for push notification processing
resource "aws_lambda_function" "push_processor" {
  filename         = data.archive_file.push_processor.output_path
  function_name    = "${var.name_prefix}-push-processor"
  role            = aws_iam_role.notification_lambda.arn
  handler         = "push_processor.handler"
  source_code_hash = data.archive_file.push_processor.output_base64sha256
  runtime         = "python3.11"
  timeout         = 300
  memory_size     = 512

  environment {
    variables = {
      PREFERENCES_TABLE       = aws_dynamodb_table.notification_preferences.name
      HISTORY_TABLE          = aws_dynamodb_table.notification_history.name
      FCM_SERVER_KEY         = var.fcm_server_key
      APNS_CERTIFICATE_ARN   = var.apns_certificate_arn
      REDIS_ENDPOINT         = var.redis_endpoint
      MAX_BATCH_SIZE         = var.max_notification_batch_size
    }
  }

  reserved_concurrent_executions = var.lambda_concurrent_executions

  tags = var.tags
}

# Lambda function for email notification processing
resource "aws_lambda_function" "email_processor" {
  filename         = data.archive_file.email_processor.output_path
  function_name    = "${var.name_prefix}-email-processor"
  role            = aws_iam_role.notification_lambda.arn
  handler         = "email_processor.handler"
  source_code_hash = data.archive_file.email_processor.output_base64sha256
  runtime         = "python3.11"
  timeout         = 300
  memory_size     = 512

  environment {
    variables = {
      PREFERENCES_TABLE = aws_dynamodb_table.notification_preferences.name
      HISTORY_TABLE    = aws_dynamodb_table.notification_history.name
      SES_REGION       = var.aws_region
      FROM_EMAIL       = var.from_email_address
      TEMPLATE_BUCKET  = aws_s3_bucket.email_templates.bucket
    }
  }

  reserved_concurrent_executions = var.lambda_concurrent_executions

  tags = var.tags
}

# Lambda function for SMS processing
resource "aws_lambda_function" "sms_processor" {
  filename         = data.archive_file.sms_processor.output_path
  function_name    = "${var.name_prefix}-sms-processor"
  role            = aws_iam_role.notification_lambda.arn
  handler         = "sms_processor.handler"
  source_code_hash = data.archive_file.sms_processor.output_base64sha256
  runtime         = "python3.11"
  timeout         = 300
  memory_size     = 512

  environment {
    variables = {
      PREFERENCES_TABLE = aws_dynamodb_table.notification_preferences.name
      HISTORY_TABLE    = aws_dynamodb_table.notification_history.name
      SNS_REGION       = var.aws_region
      SMS_SENDER_ID    = var.sms_sender_id
    }
  }

  reserved_concurrent_executions = var.lambda_concurrent_executions

  tags = var.tags
}

# Lambda function for in-app notification processing
resource "aws_lambda_function" "in_app_processor" {
  filename         = data.archive_file.in_app_processor.output_path
  function_name    = "${var.name_prefix}-in-app-processor"
  role            = aws_iam_role.notification_lambda.arn
  handler         = "in_app_processor.handler"
  source_code_hash = data.archive_file.in_app_processor.output_base64sha256
  runtime         = "python3.11"
  timeout         = 300
  memory_size     = 512

  environment {
    variables = {
      PREFERENCES_TABLE = aws_dynamodb_table.notification_preferences.name
      HISTORY_TABLE    = aws_dynamodb_table.notification_history.name
      REDIS_ENDPOINT   = var.redis_endpoint
      WEBSOCKET_API_ENDPOINT = var.websocket_api_endpoint
    }
  }

  reserved_concurrent_executions = var.lambda_concurrent_executions

  tags = var.tags
}

# S3 bucket for email templates
resource "aws_s3_bucket" "email_templates" {
  bucket = "${var.name_prefix}-email-templates-${random_id.bucket_suffix.hex}"
  tags   = var.tags
}

resource "random_id" "bucket_suffix" {
  byte_length = 4
}

resource "aws_s3_bucket_versioning" "email_templates" {
  bucket = aws_s3_bucket.email_templates.id
  versioning_configuration {
    status = "Enabled"
  }
}

# SQS event source mappings
resource "aws_lambda_event_source_mapping" "notification_processing" {
  event_source_arn = aws_sqs_queue.notification_processing.arn
  function_name    = aws_lambda_function.push_processor.arn
  batch_size       = 10
  
  maximum_batching_window_in_seconds = 5
}

resource "aws_lambda_event_source_mapping" "priority_notifications" {
  event_source_arn = aws_sqs_queue.priority_notifications.arn
  function_name    = aws_lambda_function.push_processor.arn
  batch_size       = 5
  
  maximum_batching_window_in_seconds = 1
}

# SNS topic subscriptions for Lambda triggers
resource "aws_sns_topic_subscription" "push_notifications" {
  topic_arn = aws_sns_topic.push_notifications.arn
  protocol  = "lambda"
  endpoint  = aws_lambda_function.push_processor.arn
}

resource "aws_sns_topic_subscription" "email_notifications" {
  topic_arn = aws_sns_topic.email_notifications.arn
  protocol  = "lambda"
  endpoint  = aws_lambda_function.email_processor.arn
}

resource "aws_sns_topic_subscription" "sms_notifications" {
  topic_arn = aws_sns_topic.sms_notifications.arn
  protocol  = "lambda"
  endpoint  = aws_lambda_function.sms_processor.arn
}

resource "aws_sns_topic_subscription" "in_app_notifications" {
  topic_arn = aws_sns_topic.in_app_notifications.arn
  protocol  = "lambda"
  endpoint  = aws_lambda_function.in_app_processor.arn
}

# Lambda permissions for SNS
resource "aws_lambda_permission" "allow_sns_push" {
  statement_id  = "AllowExecutionFromSNS"
  action        = "lambda:InvokeFunction"
  function_name = aws_lambda_function.push_processor.function_name
  principal     = "sns.amazonaws.com"
  source_arn    = aws_sns_topic.push_notifications.arn
}

resource "aws_lambda_permission" "allow_sns_email" {
  statement_id  = "AllowExecutionFromSNS"
  action        = "lambda:InvokeFunction"
  function_name = aws_lambda_function.email_processor.function_name
  principal     = "sns.amazonaws.com"
  source_arn    = aws_sns_topic.email_notifications.arn
}

resource "aws_lambda_permission" "allow_sns_sms" {
  statement_id  = "AllowExecutionFromSNS"
  action        = "lambda:InvokeFunction"
  function_name = aws_lambda_function.sms_processor.function_name
  principal     = "sns.amazonaws.com"
  source_arn    = aws_sns_topic.sms_notifications.arn
}

resource "aws_lambda_permission" "allow_sns_in_app" {
  statement_id  = "AllowExecutionFromSNS"
  action        = "lambda:InvokeFunction"
  function_name = aws_lambda_function.in_app_processor.function_name
  principal     = "sns.amazonaws.com"
  source_arn    = aws_sns_topic.in_app_notifications.arn
}

# IAM role for notification Lambda functions
resource "aws_iam_role" "notification_lambda" {
  name = "${var.name_prefix}-notification-lambda-role"

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

resource "aws_iam_role_policy" "notification_lambda" {
  name = "${var.name_prefix}-notification-lambda-policy"
  role = aws_iam_role.notification_lambda.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Action = [
          "dynamodb:GetItem",
          "dynamodb:PutItem",
          "dynamodb:UpdateItem",
          "dynamodb:Query",
          "dynamodb:Scan"
        ]
        Resource = [
          aws_dynamodb_table.notification_preferences.arn,
          aws_dynamodb_table.notification_history.arn,
          "${aws_dynamodb_table.notification_preferences.arn}/index/*",
          "${aws_dynamodb_table.notification_history.arn}/index/*"
        ]
      },
      {
        Effect = "Allow"
        Action = [
          "sns:Publish"
        ]
        Resource = "*"
      },
      {
        Effect = "Allow"
        Action = [
          "ses:SendEmail",
          "ses:SendTemplatedEmail",
          "ses:SendRawEmail"
        ]
        Resource = "*"
      },
      {
        Effect = "Allow"
        Action = [
          "s3:GetObject"
        ]
        Resource = "${aws_s3_bucket.email_templates.arn}/*"
      },
      {
        Effect = "Allow"
        Action = [
          "sqs:ReceiveMessage",
          "sqs:DeleteMessage",
          "sqs:GetQueueAttributes",
          "sqs:SendMessage"
        ]
        Resource = [
          aws_sqs_queue.notification_processing.arn,
          aws_sqs_queue.priority_notifications.arn,
          aws_sqs_queue.notification_dlq.arn,
          aws_sqs_queue.priority_dlq.arn
        ]
      }
    ]
  })
}

resource "aws_iam_role_policy_attachment" "notification_lambda_basic" {
  role       = aws_iam_role.notification_lambda.name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AWSLambdaBasicExecutionRole"
}

# CloudWatch alarms for monitoring
resource "aws_cloudwatch_metric_alarm" "notification_errors" {
  alarm_name          = "${var.name_prefix}-notification-errors"
  comparison_operator = "GreaterThanThreshold"
  evaluation_periods  = "2"
  metric_name         = "Errors"
  namespace           = "AWS/Lambda"
  period              = "300"
  statistic           = "Sum"
  threshold           = "10"
  alarm_description   = "High error rate in notification processing"
  alarm_actions       = var.alarm_actions

  dimensions = {
    FunctionName = aws_lambda_function.push_processor.function_name
  }

  tags = var.tags
}

resource "aws_cloudwatch_metric_alarm" "notification_queue_depth" {
  alarm_name          = "${var.name_prefix}-notification-queue-depth"
  comparison_operator = "GreaterThanThreshold"
  evaluation_periods  = "2"
  metric_name         = "ApproximateNumberOfMessages"
  namespace           = "AWS/SQS"
  period              = "300"
  statistic           = "Average"
  threshold           = "1000"
  alarm_description   = "High number of messages in notification queue"
  alarm_actions       = var.alarm_actions

  dimensions = {
    QueueName = aws_sqs_queue.notification_processing.name
  }

  tags = var.tags
}

# EventBridge rules for notification scheduling
resource "aws_cloudwatch_event_rule" "notification_scheduler" {
  name                = "${var.name_prefix}-notification-scheduler"
  description         = "Schedule periodic notification processing"
  schedule_expression = "rate(1 minute)"

  tags = var.tags
}

resource "aws_cloudwatch_event_target" "notification_scheduler_target" {
  rule      = aws_cloudwatch_event_rule.notification_scheduler.name
  target_id = "NotificationSchedulerTarget"
  arn       = aws_lambda_function.notification_scheduler.arn
}

# Lambda function for notification scheduling and batching
resource "aws_lambda_function" "notification_scheduler" {
  filename         = data.archive_file.notification_scheduler.output_path
  function_name    = "${var.name_prefix}-notification-scheduler"
  role            = aws_iam_role.notification_lambda.arn
  handler         = "notification_scheduler.handler"
  source_code_hash = data.archive_file.notification_scheduler.output_base64sha256
  runtime         = "python3.11"
  timeout         = 300
  memory_size     = 512

  environment {
    variables = {
      PREFERENCES_TABLE    = aws_dynamodb_table.notification_preferences.name
      HISTORY_TABLE       = aws_dynamodb_table.notification_history.name
      PROCESSING_QUEUE    = aws_sqs_queue.notification_processing.url
      PRIORITY_QUEUE      = aws_sqs_queue.priority_notifications.url
      REDIS_ENDPOINT      = var.redis_endpoint
      BATCH_SIZE          = var.max_notification_batch_size
      RATE_LIMIT_PER_USER = var.rate_limit_per_user
    }
  }

  tags = var.tags
}

resource "aws_lambda_permission" "allow_eventbridge_scheduler" {
  statement_id  = "AllowExecutionFromEventBridge"
  action        = "lambda:InvokeFunction"
  function_name = aws_lambda_function.notification_scheduler.function_name
  principal     = "events.amazonaws.com"
  source_arn    = aws_cloudwatch_event_rule.notification_scheduler.arn
}

# API Gateway for notification management
resource "aws_apigatewayv2_api" "notification_api" {
  name          = "${var.name_prefix}-notification-api"
  protocol_type = "HTTP"
  description   = "Notification preferences and management API"

  cors_configuration {
    allow_credentials = true
    allow_headers     = ["content-type", "authorization"]
    allow_methods     = ["GET", "POST", "PUT", "DELETE", "OPTIONS"]
    allow_origins     = ["https://${var.domain_name}"]
    max_age          = 300
  }

  tags = var.tags
}

# Lambda function for notification API
resource "aws_lambda_function" "notification_api" {
  filename         = data.archive_file.notification_api.output_path
  function_name    = "${var.name_prefix}-notification-api"
  role            = aws_iam_role.notification_lambda.arn
  handler         = "notification_api.handler"
  source_code_hash = data.archive_file.notification_api.output_base64sha256
  runtime         = "python3.11"
  timeout         = 30
  memory_size     = 256

  environment {
    variables = {
      PREFERENCES_TABLE = aws_dynamodb_table.notification_preferences.name
      HISTORY_TABLE    = aws_dynamodb_table.notification_history.name
    }
  }

  tags = var.tags
}

# API Gateway integration
resource "aws_apigatewayv2_integration" "notification_api" {
  api_id             = aws_apigatewayv2_api.notification_api.id
  integration_type   = "AWS_PROXY"
  integration_method = "POST"
  integration_uri    = aws_lambda_function.notification_api.invoke_arn
}

# API routes
resource "aws_apigatewayv2_route" "get_preferences" {
  api_id    = aws_apigatewayv2_api.notification_api.id
  route_key = "GET /preferences/{user_id}"
  target    = "integrations/${aws_apigatewayv2_integration.notification_api.id}"
}

resource "aws_apigatewayv2_route" "update_preferences" {
  api_id    = aws_apigatewayv2_api.notification_api.id
  route_key = "PUT /preferences/{user_id}"
  target    = "integrations/${aws_apigatewayv2_integration.notification_api.id}"
}

resource "aws_apigatewayv2_route" "send_notification" {
  api_id    = aws_apigatewayv2_api.notification_api.id
  route_key = "POST /send"
  target    = "integrations/${aws_apigatewayv2_integration.notification_api.id}"
}

resource "aws_apigatewayv2_route" "notification_history" {
  api_id    = aws_apigatewayv2_api.notification_api.id
  route_key = "GET /history/{user_id}"
  target    = "integrations/${aws_apigatewayv2_integration.notification_api.id}"
}

# API stage
resource "aws_apigatewayv2_stage" "notification_api" {
  api_id      = aws_apigatewayv2_api.notification_api.id
  name        = var.environment
  auto_deploy = true

  access_log_settings {
    destination_arn = aws_cloudwatch_log_group.notification_api.arn
    format = jsonencode({
      requestId      = "$context.requestId"
      ip             = "$context.identity.sourceIp"
      requestTime    = "$context.requestTime"
      httpMethod     = "$context.httpMethod"
      routeKey       = "$context.routeKey"
      status         = "$context.status"
      protocol       = "$context.protocol"
      responseLength = "$context.responseLength"
      responseTime   = "$context.responseTime"
    })
  }

  tags = var.tags
}

resource "aws_lambda_permission" "allow_api_gateway" {
  statement_id  = "AllowExecutionFromAPIGateway"
  action        = "lambda:InvokeFunction"
  function_name = aws_lambda_function.notification_api.function_name
  principal     = "apigateway.amazonaws.com"
  source_arn    = "${aws_apigatewayv2_api.notification_api.execution_arn}/*/*/*"
}

# CloudWatch Log Group for API Gateway
resource "aws_cloudwatch_log_group" "notification_api" {
  name              = "/aws/apigateway/${var.name_prefix}-notification"
  retention_in_days = 14

  tags = merge(var.tags, {
    Name = "${var.name_prefix}-notification-api-logs"
  })
}

# Lambda function packages (placeholders)
data "archive_file" "push_processor" {
  type        = "zip"
  output_path = "/tmp/push_processor.zip"
  source {
    content  = file("${path.module}/lambda/push_processor.py")
    filename = "push_processor.py"
  }
}

data "archive_file" "email_processor" {
  type        = "zip"
  output_path = "/tmp/email_processor.zip"
  source {
    content  = file("${path.module}/lambda/email_processor.py")
    filename = "email_processor.py"
  }
}

data "archive_file" "sms_processor" {
  type        = "zip"
  output_path = "/tmp/sms_processor.zip"
  source {
    content  = file("${path.module}/lambda/sms_processor.py")
    filename = "sms_processor.py"
  }
}

data "archive_file" "in_app_processor" {
  type        = "zip"
  output_path = "/tmp/in_app_processor.zip"
  source {
    content  = file("${path.module}/lambda/in_app_processor.py")
    filename = "in_app_processor.py"
  }
}

data "archive_file" "notification_scheduler" {
  type        = "zip"
  output_path = "/tmp/notification_scheduler.zip"
  source {
    content  = file("${path.module}/lambda/notification_scheduler.py")
    filename = "notification_scheduler.py"
  }
}

data "archive_file" "notification_api" {
  type        = "zip"
  output_path = "/tmp/notification_api.zip"
  source {
    content  = file("${path.module}/lambda/notification_api.py")
    filename = "notification_api.py"
  }
}