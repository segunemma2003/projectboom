terraform {
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
  }
}

# Data classification and discovery using Amazon Macie
resource "aws_macie2_account" "main" {
  finding_publishing_frequency = "FIFTEEN_MINUTES"
  status                       = "ENABLED"
}

resource "aws_macie2_classification_job" "data_discovery" {
  job_type = "ONE_TIME"
  name     = "${var.name_prefix}-data-classification"

  s3_job_definition {
    bucket_definitions {
      account_id = data.aws_caller_identity.current.account_id
      buckets    = var.s3_buckets_for_scanning
    }
  }

  tags = var.tags
}

# Data retention policies using DynamoDB TTL and S3 lifecycle
resource "aws_dynamodb_table" "user_consent" {
  name           = "${var.name_prefix}-user-consent"
  billing_mode   = "PAY_PER_REQUEST"
  hash_key       = "user_id"
  range_key      = "consent_type"

  attribute {
    name = "user_id"
    type = "S"
  }

  attribute {
    name = "consent_type"
    type = "S"
  }

  attribute {
    name = "created_at"
    type = "S"
  }

  global_secondary_index {
    name            = "ConsentTypeIndex"
    hash_key        = "consent_type"
    range_key       = "created_at"
    projection_type = "ALL"
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
    Name        = "${var.name_prefix}-user-consent"
    DataClass   = "PersonalData"
    Compliance  = "GDPR"
  })
}

# Data subject rights management table
resource "aws_dynamodb_table" "data_subject_requests" {
  name           = "${var.name_prefix}-data-subject-requests"
  billing_mode   = "PAY_PER_REQUEST"
  hash_key       = "request_id"

  attribute {
    name = "request_id"
    type = "S"
  }

  attribute {
    name = "user_id"
    type = "S"
  }

  attribute {
    name = "request_type"
    type = "S"
  }

  attribute {
    name = "status"
    type = "S"
  }

  attribute {
    name = "created_at"
    type = "S"
  }

  global_secondary_index {
    name            = "UserRequestsIndex"
    hash_key        = "user_id"
    range_key       = "created_at"
    projection_type = "ALL"
  }

  global_secondary_index {
    name            = "RequestTypeIndex"
    hash_key        = "request_type"
    range_key       = "created_at"
    projection_type = "ALL"
  }

  global_secondary_index {
    name            = "StatusIndex"
    hash_key        = "status"
    range_key       = "created_at"
    projection_type = "KEYS_ONLY"
  }

  point_in_time_recovery {
    enabled = true
  }

  server_side_encryption {
    enabled = true
  }

  tags = merge(var.tags, {
    Name        = "${var.name_prefix}-data-subject-requests"
    DataClass   = "PersonalData"
    Compliance  = "GDPR"
  })
}

# Audit logging table for compliance tracking
resource "aws_dynamodb_table" "audit_log" {
  name           = "${var.name_prefix}-audit-log"
  billing_mode   = "PAY_PER_REQUEST"
  hash_key       = "log_id"
  range_key      = "timestamp"

  attribute {
    name = "log_id"
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
    name = "action_type"
    type = "S"
  }

  global_secondary_index {
    name            = "UserActionIndex"
    hash_key        = "user_id"
    range_key       = "timestamp"
    projection_type = "ALL"
  }

  global_secondary_index {
    name            = "ActionTypeIndex"
    hash_key        = "action_type"
    range_key       = "timestamp"
    projection_type = "ALL"
  }

  # Retain audit logs for 7 years (GDPR requirement)
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
    Name        = "${var.name_prefix}-audit-log"
    DataClass   = "AuditData"
    Compliance  = "GDPR"
    Retention   = "7years"
  })
}

# Lambda function for data subject rights processing
resource "aws_lambda_function" "data_rights_processor" {
  filename         = data.archive_file.data_rights_processor.output_path
  function_name    = "${var.name_prefix}-data-rights-processor"
  role            = aws_iam_role.data_rights_lambda.arn
  handler         = "data_rights_processor.handler"
  source_code_hash = data.archive_file.data_rights_processor.output_base64sha256
  runtime         = "python3.11"
  timeout         = 900 # 15 minutes for complex data operations

  environment {
    variables = {
      CONSENT_TABLE           = aws_dynamodb_table.user_consent.name
      REQUESTS_TABLE          = aws_dynamodb_table.data_subject_requests.name
      AUDIT_TABLE            = aws_dynamodb_table.audit_log.name
      USER_DATA_BUCKETS      = jsonencode(var.user_data_s3_buckets)
      CHAT_MESSAGES_TABLE    = var.chat_messages_table_name
      USER_PROFILES_TABLE    = var.user_profiles_table_name
      NOTIFICATION_TOPIC     = aws_sns_topic.compliance_notifications.arn
      ENCRYPTION_KEY_ID      = aws_kms_key.compliance_encryption.key_id
    }
  }

  vpc_config {
    subnet_ids         = var.subnet_ids
    security_group_ids = [aws_security_group.compliance_lambda.id]
  }

  reserved_concurrent_executions = 10

  tags = merge(var.tags, {
    Purpose = "DataRightsProcessing"
    Compliance = "GDPR"
  })
}

# Lambda function for automated data retention
resource "aws_lambda_function" "data_retention_processor" {
  filename         = data.archive_file.data_retention_processor.output_path
  function_name    = "${var.name_prefix}-data-retention-processor"
  role            = aws_iam_role.data_rights_lambda.arn
  handler         = "data_retention_processor.handler"
  source_code_hash = data.archive_file.data_retention_processor.output_base64sha256
  runtime         = "python3.11"
  timeout         = 900

  environment {
    variables = {
      AUDIT_TABLE           = aws_dynamodb_table.audit_log.name
      USER_DATA_BUCKETS     = jsonencode(var.user_data_s3_buckets)
      RETENTION_POLICIES    = jsonencode(var.data_retention_policies)
      NOTIFICATION_TOPIC    = aws_sns_topic.compliance_notifications.arn
    }
  }

  vpc_config {
    subnet_ids         = var.subnet_ids
    security_group_ids = [aws_security_group.compliance_lambda.id]
  }

  tags = merge(var.tags, {
    Purpose = "DataRetention"
    Compliance = "GDPR"
  })
}

# EventBridge rules for automated compliance processes
resource "aws_cloudwatch_event_rule" "daily_data_retention" {
  name                = "${var.name_prefix}-daily-data-retention"
  description         = "Trigger daily data retention cleanup"
  schedule_expression = "cron(0 2 * * ? *)" # Daily at 2 AM UTC

  tags = var.tags
}

resource "aws_cloudwatch_event_target" "data_retention_target" {
  rule      = aws_cloudwatch_event_rule.daily_data_retention.name
  target_id = "DataRetentionProcessor"
  arn       = aws_lambda_function.data_retention_processor.arn
}

resource "aws_lambda_permission" "allow_eventbridge_data_retention" {
  statement_id  = "AllowExecutionFromEventBridge"
  action        = "lambda:InvokeFunction"
  function_name = aws_lambda_function.data_retention_processor.function_name
  principal     = "events.amazonaws.com"
  source_arn    = aws_cloudwatch_event_rule.daily_data_retention.arn
}

# SQS queue for data subject requests
resource "aws_sqs_queue" "data_subject_requests" {
  name                      = "${var.name_prefix}-data-subject-requests"
  delay_seconds             = 0
  max_message_size          = 262144
  message_retention_seconds = 1209600
  receive_wait_time_seconds = 20

  redrive_policy = jsonencode({
    deadLetterTargetArn = aws_sqs_queue.data_subject_requests_dlq.arn
    maxReceiveCount     = 3
  })

  tags = merge(var.tags, {
    Purpose = "DataSubjectRights"
    Compliance = "GDPR"
  })
}

resource "aws_sqs_queue" "data_subject_requests_dlq" {
  name = "${var.name_prefix}-data-subject-requests-dlq"
  tags = var.tags
}

# SQS event source mapping for data rights processor
resource "aws_lambda_event_source_mapping" "data_rights_processor" {
  event_source_arn = aws_sqs_queue.data_subject_requests.arn
  function_name    = aws_lambda_function.data_rights_processor.arn
  batch_size       = 5
  
  maximum_batching_window_in_seconds = 10
}

# SNS topic for compliance notifications
resource "aws_sns_topic" "compliance_notifications" {
  name = "${var.name_prefix}-compliance-notifications"
  
  kms_master_key_id = aws_kms_key.compliance_encryption.id

  tags = var.tags
}

resource "aws_sns_topic_subscription" "compliance_email" {
  count     = length(var.compliance_notification_emails)
  topic_arn = aws_sns_topic.compliance_notifications.arn
  protocol  = "email"
  endpoint  = var.compliance_notification_emails[count.index]
}

# KMS key for compliance encryption
resource "aws_kms_key" "compliance_encryption" {
  description             = "KMS key for compliance data encryption"
  deletion_window_in_days = 7

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Sid    = "Enable IAM User Permissions"
        Effect = "Allow"
        Principal = {
          AWS = "arn:aws:iam::${data.aws_caller_identity.current.account_id}:root"
        }
        Action   = "kms:*"
        Resource = "*"
      },
      {
        Sid    = "Allow compliance services"
        Effect = "Allow"
        Principal = {
          Service = [
            "lambda.amazonaws.com",
            "sns.amazonaws.com",
            "sqs.amazonaws.com",
            "dynamodb.amazonaws.com"
          ]
        }
        Action = [
          "kms:Decrypt",
          "kms:GenerateDataKey"
        ]
        Resource = "*"
      }
    ]
  })

  tags = merge(var.tags, {
    Name = "${var.name_prefix}-compliance-encryption"
    Purpose = "ComplianceDataEncryption"
  })
}

resource "aws_kms_alias" "compliance_encryption" {
  name          = "alias/${var.name_prefix}-compliance"
  target_key_id = aws_kms_key.compliance_encryption.key_id
}

# Security group for compliance Lambda functions
resource "aws_security_group" "compliance_lambda" {
  name_prefix = "${var.name_prefix}-compliance-lambda-"
  vpc_id      = var.vpc_id

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  egress {
    from_port   = 443
    to_port     = 443
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = merge(var.tags, {
    Name = "${var.name_prefix}-compliance-lambda-sg"
  })

  lifecycle {
    create_before_destroy = true
  }
}

# IAM role for compliance Lambda functions
resource "aws_iam_role" "data_rights_lambda" {
  name = "${var.name_prefix}-data-rights-lambda-role"

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

resource "aws_iam_role_policy" "data_rights_lambda" {
  name = "${var.name_prefix}-data-rights-lambda-policy"
  role = aws_iam_role.data_rights_lambda.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Action = [
          "dynamodb:GetItem",
          "dynamodb:PutItem",
          "dynamodb:UpdateItem",
          "dynamodb:DeleteItem",
          "dynamodb:Query",
          "dynamodb:Scan",
          "dynamodb:BatchGetItem",
          "dynamodb:BatchWriteItem"
        ]
        Resource = [
          aws_dynamodb_table.user_consent.arn,
          aws_dynamodb_table.data_subject_requests.arn,
          aws_dynamodb_table.audit_log.arn,
          "${aws_dynamodb_table.user_consent.arn}/index/*",
          "${aws_dynamodb_table.data_subject_requests.arn}/index/*",
          "${aws_dynamodb_table.audit_log.arn}/index/*"
        ]
      },
      {
        Effect = "Allow"
        Action = [
          "s3:GetObject",
          "s3:DeleteObject",
          "s3:ListBucket",
          "s3:GetObjectVersion",
          "s3:DeleteObjectVersion"
        ]
        Resource = flatten([
          for bucket in var.user_data_s3_buckets : [
            "arn:aws:s3:::${bucket}",
            "arn:aws:s3:::${bucket}/*"
          ]
        ])
      },
      {
        Effect = "Allow"
        Action = [
          "sns:Publish"
        ]
        Resource = aws_sns_topic.compliance_notifications.arn
      },
      {
        Effect = "Allow"
        Action = [
          "sqs:ReceiveMessage",
          "sqs:DeleteMessage",
          "sqs:GetQueueAttributes"
        ]
        Resource = [
          aws_sqs_queue.data_subject_requests.arn,
          aws_sqs_queue.data_subject_requests_dlq.arn
        ]
      },
      {
        Effect = "Allow"
        Action = [
          "kms:Decrypt",
          "kms:GenerateDataKey",
          "kms:DescribeKey"
        ]
        Resource = aws_kms_key.compliance_encryption.arn
      }
    ]
  })
}

resource "aws_iam_role_policy_attachment" "data_rights_lambda_vpc" {
  role       = aws_iam_role.data_rights_lambda.name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AWSLambdaVPCAccessExecutionRole"
}

# CloudWatch alarms for compliance monitoring
resource "aws_cloudwatch_metric_alarm" "data_request_processing_errors" {
  alarm_name          = "${var.name_prefix}-data-request-errors"
  comparison_operator = "GreaterThanThreshold"
  evaluation_periods  = "2"
  metric_name         = "Errors"
  namespace           = "AWS/Lambda"
  period              = "300"
  statistic           = "Sum"
  threshold           = "5"
  alarm_description   = "High error rate in data rights processing"
  alarm_actions       = [aws_sns_topic.compliance_notifications.arn]

  dimensions = {
    FunctionName = aws_lambda_function.data_rights_processor.function_name
  }

  tags = var.tags
}

resource "aws_cloudwatch_metric_alarm" "data_request_duration" {
  alarm_name          = "${var.name_prefix}-data-request-duration"
  comparison_operator = "GreaterThanThreshold"
  evaluation_periods  = "2"
  metric_name         = "Duration"
  namespace           = "AWS/Lambda"
  period              = "300"
  statistic           = "Average"
  threshold           = "600000" # 10 minutes
  alarm_description   = "Data rights processing taking too long"
  alarm_actions       = [aws_sns_topic.compliance_notifications.arn]

  dimensions = {
    FunctionName = aws_lambda_function.data_rights_processor.function_name
  }

  tags = var.tags
}

# API Gateway for data subject rights requests
resource "aws_apigatewayv2_api" "compliance_api" {
  name          = "${var.name_prefix}-compliance-api"
  protocol_type = "HTTP"
  description   = "API for GDPR compliance and data subject rights"

  cors_configuration {
    allow_credentials = true
    allow_headers     = ["content-type", "authorization"]
    allow_methods     = ["POST", "GET", "OPTIONS"]
    allow_origins     = ["https://${var.domain_name}"]
    max_age          = 300
  }

  tags = var.tags
}

resource "aws_apigatewayv2_integration" "compliance_lambda" {
  api_id             = aws_apigatewayv2_api.compliance_api.id
  integration_type   = "AWS_PROXY"
  integration_method = "POST"
  integration_uri    = aws_lambda_function.data_rights_processor.invoke_arn
}

resource "aws_apigatewayv2_route" "data_request" {
  api_id    = aws_apigatewayv2_api.compliance_api.id
  route_key = "POST /data-request"
  target    = "integrations/${aws_apigatewayv2_integration.compliance_lambda.id}"
}

resource "aws_apigatewayv2_route" "consent_management" {
  api_id    = aws_apigatewayv2_api.compliance_api.id
  route_key = "POST /consent"
  target    = "integrations/${aws_apigatewayv2_integration.compliance_lambda.id}"
}

resource "aws_apigatewayv2_stage" "compliance_api" {
  api_id      = aws_apigatewayv2_api.compliance_api.id
  name        = "v1"
  auto_deploy = true

  access_log_settings {
    destination_arn = aws_cloudwatch_log_group.compliance_api.arn
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

resource "aws_lambda_permission" "compliance_api_lambda" {
  statement_id  = "AllowExecutionFromAPIGateway"
  action        = "lambda:InvokeFunction"
  function_name = aws_lambda_function.data_rights_processor.function_name
  principal     = "apigateway.amazonaws.com"
  source_arn    = "${aws_apigatewayv2_api.compliance_api.execution_arn}/*/*/*"
}

# CloudWatch Log Group for Compliance API
resource "aws_cloudwatch_log_group" "compliance_api" {
  name              = "/aws/apigateway/${var.name_prefix}-compliance"
  retention_in_days = 14

  tags = merge(var.tags, {
    Name = "${var.name_prefix}-compliance-api-logs"
  })
}

# Data anonymization job using AWS Glue
resource "aws_glue_job" "data_anonymization" {
  name     = "${var.name_prefix}-data-anonymization"
  role_arn = aws_iam_role.glue_anonymization.arn

  command {
    script_location = "s3://${var.scripts_bucket}/anonymization_script.py"
    python_version  = "3"
  }

  default_arguments = {
    "--job-bookmark-option"           = "job-bookmark-enable"
    "--TempDir"                      = "s3://${var.temp_bucket}/temp/"
    "--enable-metrics"               = ""
    "--enable-continuous-cloudwatch-log" = "true"
    "--source_database"              = var.source_database_name
    "--target_database"              = var.anonymized_database_name
  }

  execution_property {
    max_concurrent_runs = 2
  }

  tags = var.tags
}

# IAM role for Glue anonymization job
resource "aws_iam_role" "glue_anonymization" {
  name = "${var.name_prefix}-glue-anonymization-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action = "sts:AssumeRole"
        Effect = "Allow"
        Principal = {
          Service = "glue.amazonaws.com"
        }
      }
    ]
  })

  tags = var.tags
}

resource "aws_iam_role_policy_attachment" "glue_service_role" {
  role       = aws_iam_role.glue_anonymization.name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AWSGlueServiceRole"
}

# Package Lambda functions
data "archive_file" "data_rights_processor" {
  type        = "zip"
  output_path = "/tmp/data_rights_processor.zip"
  source {
    content  = file("${path.module}/lambda/data_rights_processor.py")
    filename = "data_rights_processor.py"
  }
}

data "archive_file" "data_retention_processor" {
  type        = "zip"
  output_path = "/tmp/data_retention_processor.zip"
  source {
    content  = file("${path.module}/lambda/data_retention_processor.py")
    filename = "data_retention_processor.py"
  }
}

# Get current AWS account ID and region
data "aws_caller_identity" "current" {}
data "aws_region" "current" {}