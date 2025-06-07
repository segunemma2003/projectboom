# modules/chat/sqs-sns.tf - Enhanced message processing
resource "aws_sqs_queue" "message_processing" {
  name                      = "${var.name_prefix}-message-processing"
  delay_seconds             = 0
  max_message_size          = 262144
  message_retention_seconds = 1209600
  receive_wait_time_seconds = 20

  # Dead letter queue configuration
  redrive_policy = jsonencode({
    deadLetterTargetArn = aws_sqs_queue.message_dlq.arn
    maxReceiveCount     = 3
  })

  tags = var.tags
}

resource "aws_sqs_queue" "message_dlq" {
  name = "${var.name_prefix}-message-dlq"
  tags = var.tags
}

# FIFO queue for group chat ordering
resource "aws_sqs_queue" "group_chat_fifo" {
  name                        = "${var.name_prefix}-group-chat.fifo"
  fifo_queue                  = true
  content_based_deduplication = true
  
  redrive_policy = jsonencode({
    deadLetterTargetArn = aws_sqs_queue.group_chat_dlq.arn
    maxReceiveCount     = 3
  })

  tags = var.tags
}

resource "aws_sqs_queue" "group_chat_dlq" {
  name       = "${var.name_prefix}-group-chat-dlq.fifo"
  fifo_queue = true
  tags       = var.tags
}

# SNS Topics for notifications
resource "aws_sns_topic" "chat_notifications" {
  name = "${var.name_prefix}-chat-notifications"
  
  # Enable encryption
  kms_master_key_id = aws_kms_key.chat_encryption.id

  tags = var.tags
}

resource "aws_sns_topic" "group_chat_notifications" {
  name       = "${var.name_prefix}-group-chat-notifications.fifo"
  fifo_topic = true
  
  # Enable encryption
  kms_master_key_id = aws_kms_key.chat_encryption.id

  tags = var.tags
}

# Lambda function for message processing
resource "aws_lambda_function" "message_processor" {
  filename         = data.archive_file.message_processor.output_path
  function_name    = "${var.name_prefix}-message-processor"
  role            = aws_iam_role.lambda_execution.arn
  handler         = "message_processor.handler"
  source_code_hash = data.archive_file.message_processor.output_base64sha256
  runtime         = "python3.11"
  timeout         = 60

  environment {
    variables = {
      CHAT_MESSAGES_TABLE       = aws_dynamodb_table.chat_messages.name
      CONVERSATIONS_TABLE       = aws_dynamodb_table.conversations.name
      USER_CONVERSATIONS_TABLE  = aws_dynamodb_table.user_conversations.name
      USER_PRESENCE_TABLE       = aws_dynamodb_table.user_presence.name
      CHAT_NOTIFICATIONS_TOPIC  = aws_sns_topic.chat_notifications.arn
      GROUP_NOTIFICATIONS_TOPIC = aws_sns_topic.group_chat_notifications.arn
      REDIS_ENDPOINT            = var.redis_realtime_endpoint
    }
  }

  # VPC configuration for Redis access
  dynamic "vpc_config" {
    for_each = var.vpc_id != "" ? [1] : []
    content {
      subnet_ids         = var.subnet_ids
      security_group_ids = [aws_security_group.lambda.id]
    }
  }

  reserved_concurrent_executions = var.lambda_reserved_concurrency

  tags = var.tags
}

# Lambda function for presence management
resource "aws_lambda_function" "presence_manager" {
  filename         = data.archive_file.presence_manager.output_path
  function_name    = "${var.name_prefix}-presence-manager"
  role            = aws_iam_role.lambda_execution.arn
  handler         = "presence_manager.handler"
  source_code_hash = data.archive_file.presence_manager.output_base64sha256
  runtime         = "python3.11"
  timeout         = 30

  environment {
    variables = {
      USER_PRESENCE_TABLE = aws_dynamodb_table.user_presence.name
      REDIS_ENDPOINT      = var.redis_realtime_endpoint
    }
  }

  # VPC configuration for Redis access
  dynamic "vpc_config" {
    for_each = var.vpc_id != "" ? [1] : []
    content {
      subnet_ids         = var.subnet_ids
      security_group_ids = [aws_security_group.lambda.id]
    }
  }

  tags = var.tags
}

# SQS event source mapping
resource "aws_lambda_event_source_mapping" "message_processor" {
  event_source_arn = aws_sqs_queue.message_processing.arn
  function_name    = aws_lambda_function.message_processor.arn
  batch_size       = 10
  
  # Error handling
  maximum_batching_window_in_seconds = 5
  
  depends_on = [aws_iam_role_policy_attachment.lambda_sqs_execution]
}

# EventBridge for real-time events
resource "aws_cloudwatch_event_rule" "user_activity" {
  name        = "${var.name_prefix}-user-activity"
  description = "Capture user activity events"

  event_pattern = jsonencode({
    source      = ["social-platform"]
    detail-type = ["User Activity", "Message Sent", "User Online", "User Offline"]
  })

  tags = var.tags
}

resource "aws_cloudwatch_event_target" "presence_lambda" {
  rule      = aws_cloudwatch_event_rule.user_activity.name
  target_id = "PresenceManagerTarget"
  arn       = aws_lambda_function.presence_manager.arn
}

resource "aws_lambda_permission" "allow_eventbridge" {
  statement_id  = "AllowExecutionFromEventBridge"
  action        = "lambda:InvokeFunction"
  function_name = aws_lambda_function.presence_manager.function_name
  principal     = "events.amazonaws.com"
  source_arn    = aws_cloudwatch_event_rule.user_activity.arn
}

# Security group for Lambda functions
resource "aws_security_group" "lambda" {
  count  = var.vpc_id != "" ? 1 : 0
  name   = "${var.name_prefix}-lambda-sg"
  vpc_id = var.vpc_id

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  egress {
    from_port   = 6379
    to_port     = 6379
    protocol    = "tcp"
    cidr_blocks = ["10.0.0.0/8"]
  }

  tags = merge(var.tags, {
    Name = "${var.name_prefix}-lambda-sg"
  })
}

# IAM role for Lambda execution
resource "aws_iam_role" "lambda_execution" {
  name = "${var.name_prefix}-lambda-execution-role"

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

# Lambda execution policy
resource "aws_iam_role_policy" "lambda_execution" {
  name = "${var.name_prefix}-lambda-execution-policy"
  role = aws_iam_role.lambda_execution.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Action = [
          "dynamodb:PutItem",
          "dynamodb:GetItem",
          "dynamodb:UpdateItem",
          "dynamodb:DeleteItem",
          "dynamodb:Query",
          "dynamodb:Scan"
        ]
        Resource = [
          aws_dynamodb_table.chat_messages.arn,
          aws_dynamodb_table.conversations.arn,
          aws_dynamodb_table.user_conversations.arn,
          aws_dynamodb_table.user_presence.arn,
          "${aws_dynamodb_table.chat_messages.arn}/index/*",
          "${aws_dynamodb_table.user_conversations.arn}/index/*"
        ]
      },
      {
        Effect = "Allow"
        Action = [
          "sns:Publish"
        ]
        Resource = [
          aws_sns_topic.chat_notifications.arn,
          aws_sns_topic.group_chat_notifications.arn
        ]
      },
      {
        Effect = "Allow"
        Action = [
          "sqs:ReceiveMessage",
          "sqs:DeleteMessage",
          "sqs:GetQueueAttributes"
        ]
        Resource = [
          aws_sqs_queue.message_processing.arn,
          aws_sqs_queue.group_chat_fifo.arn
        ]
      },
      {
        Effect = "Allow"
        Action = [
          "kms:Decrypt",
          "kms:GenerateDataKey"
        ]
        Resource = aws_kms_key.chat_encryption.arn
      }
    ]
  })
}

# Attach VPC execution policy if needed
resource "aws_iam_role_policy_attachment" "lambda_vpc_execution" {
  count      = var.vpc_id != "" ? 1 : 0
  role       = aws_iam_role.lambda_execution.name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AWSLambdaVPCAccessExecutionRole"
}

resource "aws_iam_role_policy_attachment" "lambda_sqs_execution" {
  role       = aws_iam_role.lambda_execution.name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AWSLambdaSQSQueueExecutionRole"
}

# CloudWatch alarms for monitoring
resource "aws_cloudwatch_metric_alarm" "message_queue_depth" {
  alarm_name          = "${var.name_prefix}-message-queue-depth"
  comparison_operator = "GreaterThanThreshold"
  evaluation_periods  = "2"
  metric_name         = "ApproximateNumberOfMessages"
  namespace           = "AWS/SQS"
  period              = "300"
  statistic           = "Average"
  threshold           = "1000"
  alarm_description   = "This metric monitors SQS queue depth"
  alarm_actions       = var.alarm_actions

  dimensions = {
    QueueName = aws_sqs_queue.message_processing.name
  }

  tags = var.tags
}

resource "aws_cloudwatch_metric_alarm" "lambda_errors" {
  alarm_name          = "${var.name_prefix}-lambda-errors"
  comparison_operator = "GreaterThanThreshold"
  evaluation_periods  = "2"
  metric_name         = "Errors"
  namespace           = "AWS/Lambda"
  period              = "300"
  statistic           = "Sum"
  threshold           = "10"
  alarm_description   = "This metric monitors Lambda function errors"
  alarm_actions       = var.alarm_actions

  dimensions = {
    FunctionName = aws_lambda_function.message_processor.function_name
  }

  tags = var.tags
}

# Lambda function packages
data "archive_file" "message_processor" {
  type        = "zip"
  output_path = "/tmp/message_processor.zip"
  source {
    content  = file("${path.module}/lambda/message_processor.py")
    filename = "message_processor.py"
  }
}

data "archive_file" "presence_manager" {
  type        = "zip"
  output_path = "/tmp/presence_manager.zip"
  source {
    content  = file("${path.module}/lambda/presence_manager.py")
    filename = "presence_manager.py"
  }
}

# Get current AWS account ID and region
data "aws_caller_identity" "current" {}
data "aws_region" "current" {}