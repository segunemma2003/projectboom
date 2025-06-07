terraform {
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
  }
}

# OpenSearch cluster for search functionality
resource "aws_opensearch_domain" "main" {
  domain_name    = "${var.name_prefix}-search"
  engine_version = var.engine_version

  cluster_config {
    instance_type           = var.instance_type
    instance_count         = var.instance_count
    dedicated_master_enabled = var.dedicated_master_enabled
    zone_awareness_enabled = var.zone_awareness_enabled

    dynamic "zone_awareness_config" {
      for_each = var.zone_awareness_enabled ? [1] : []
      content {
        availability_zone_count = var.availability_zone_count
      }
    }

    warm_enabled = var.warm_enabled
    warm_count   = var.warm_enabled ? var.warm_count : null
    warm_type    = var.warm_enabled ? var.warm_type : null

    cold_storage_options {
      enabled = var.cold_storage_enabled
    }
  }

  ebs_options {
    ebs_enabled = true
    volume_type = var.volume_type
    volume_size = var.volume_size
    iops        = contains(["gp3", "io1", "io2"], var.volume_type) ? var.volume_iops : null
    throughput  = var.volume_type == "gp3" ? var.volume_throughput : null
  }

  vpc_options {
    subnet_ids         = var.subnet_ids
    security_group_ids = [aws_security_group.opensearch.id]
  }

  encrypt_at_rest {
    enabled = true
  }

  node_to_node_encryption {
    enabled = true
  }

  domain_endpoint_options {
    enforce_https       = true
    tls_security_policy = "Policy-Min-TLS-1-2-2019-07"
  }

  advanced_security_options {
    enabled                        = var.fine_grained_access_control_enabled
    anonymous_auth_enabled         = false
    internal_user_database_enabled = var.internal_user_database_enabled

    dynamic "master_user_options" {
      for_each = var.fine_grained_access_control_enabled ? [1] : []
      content {
        master_user_name     = var.master_user_name
        master_user_password = var.master_user_password
      }
    }
  }

  log_publishing_options {
    cloudwatch_log_group_arn = aws_cloudwatch_log_group.opensearch_index_slow.arn
    log_type                 = "INDEX_SLOW_LOGS"
    enabled                  = true
  }

  log_publishing_options {
    cloudwatch_log_group_arn = aws_cloudwatch_log_group.opensearch_search_slow.arn
    log_type                 = "SEARCH_SLOW_LOGS"
    enabled                  = true
  }

  log_publishing_options {
    cloudwatch_log_group_arn = aws_cloudwatch_log_group.opensearch_es_application.arn
    log_type                 = "ES_APPLICATION_LOGS"
    enabled                  = true
  }

  advanced_options = {
    "rest.action.multi.allow_explicit_index" = "true"
    "indices.fielddata.cache.size"           = "20%"
    "indices.query.bool.max_clause_count"    = "1024"
  }

  tags = merge(var.tags, {
    Name = "${var.name_prefix}-opensearch"
  })

  depends_on = [
    aws_iam_service_linked_role.opensearch,
    aws_cloudwatch_log_group.opensearch_index_slow,
    aws_cloudwatch_log_group.opensearch_search_slow,
    aws_cloudwatch_log_group.opensearch_es_application
  ]
}

# Service-linked role for OpenSearch
resource "aws_iam_service_linked_role" "opensearch" {
  aws_service_name = "es.amazonaws.com"

  lifecycle {
    ignore_changes = [aws_service_name]
  }
}

# Security group for OpenSearch
resource "aws_security_group" "opensearch" {
  name_prefix = "${var.name_prefix}-opensearch-"
  vpc_id      = var.vpc_id

  ingress {
    from_port   = 443
    to_port     = 443
    protocol    = "tcp"
    cidr_blocks = [var.vpc_cidr]
    description = "HTTPS access from VPC"
  }

  dynamic "ingress" {
    for_each = length(var.allowed_security_groups) > 0 ? [1] : []
    content {
      from_port       = 443
      to_port         = 443
      protocol        = "tcp"
      security_groups = var.allowed_security_groups
      description     = "HTTPS access from allowed security groups"
    }
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
    description = "All outbound traffic"
  }

  tags = merge(var.tags, {
    Name = "${var.name_prefix}-opensearch-sg"
  })

  lifecycle {
    create_before_destroy = true
  }
}

# CloudWatch Log Groups for OpenSearch
resource "aws_cloudwatch_log_group" "opensearch_index_slow" {
  name              = "/aws/opensearch/domains/${var.name_prefix}-search/index-slow"
  retention_in_days = var.log_retention_days

  tags = var.tags
}

resource "aws_cloudwatch_log_group" "opensearch_search_slow" {
  name              = "/aws/opensearch/domains/${var.name_prefix}-search/search-slow"
  retention_in_days = var.log_retention_days

  tags = var.tags
}

resource "aws_cloudwatch_log_group" "opensearch_es_application" {
  name              = "/aws/opensearch/domains/${var.name_prefix}-search/application"
  retention_in_days = var.log_retention_days

  tags = var.tags
}

# CloudWatch Log Group for Search API
resource "aws_cloudwatch_log_group" "search_api" {
  name              = "/aws/apigateway/${var.name_prefix}-search"
  retention_in_days = var.log_retention_days

  tags = merge(var.tags, {
    Name = "${var.name_prefix}-search-api-logs"
  })
}

# DynamoDB table for search indexing metadata
resource "aws_dynamodb_table" "search_index_metadata" {
  name           = "${var.name_prefix}-search-index-metadata"
  billing_mode   = "PAY_PER_REQUEST"
  hash_key       = "index_name"
  range_key      = "document_id"

  attribute {
    name = "index_name"
    type = "S"
  }

  attribute {
    name = "document_id"
    type = "S"
  }

  attribute {
    name = "last_updated"
    type = "S"
  }

  global_secondary_index {
    name            = "LastUpdatedIndex"
    hash_key        = "index_name"
    range_key       = "last_updated"
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
    Name = "${var.name_prefix}-search-index-metadata"
  })
}

# SQS queue for search indexing jobs
resource "aws_sqs_queue" "search_indexing" {
  name                      = "${var.name_prefix}-search-indexing"
  delay_seconds             = 0
  max_message_size          = 262144
  message_retention_seconds = 1209600
  receive_wait_time_seconds = 20

  redrive_policy = jsonencode({
    deadLetterTargetArn = aws_sqs_queue.search_indexing_dlq.arn
    maxReceiveCount     = 3
  })

  tags = var.tags
}

resource "aws_sqs_queue" "search_indexing_dlq" {
  name = "${var.name_prefix}-search-indexing-dlq"
  tags = var.tags
}

# Security group for Lambda functions
resource "aws_security_group" "search_lambda" {
  name_prefix = "${var.name_prefix}-search-lambda-"
  vpc_id      = var.vpc_id

  egress {
    from_port   = 443
    to_port     = 443
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
    description = "HTTPS access to internet"
  }

  egress {
    from_port       = 443
    to_port         = 443
    protocol        = "tcp"
    security_groups = [aws_security_group.opensearch.id]
    description     = "HTTPS access to OpenSearch"
  }

  egress {
    from_port   = 6379
    to_port     = 6379
    protocol    = "tcp"
    cidr_blocks = [var.vpc_cidr]
    description = "Redis access"
  }

  tags = merge(var.tags, {
    Name = "${var.name_prefix}-search-lambda-sg"
  })

  lifecycle {
    create_before_destroy = true
  }
}

# IAM role for search Lambda functions
resource "aws_iam_role" "search_lambda" {
  name = "${var.name_prefix}-search-lambda-role"

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

resource "aws_iam_role_policy" "search_lambda" {
  name = "${var.name_prefix}-search-lambda-policy"
  role = aws_iam_role.search_lambda.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Action = [
          "es:ESHttpPost",
          "es:ESHttpPut",
          "es:ESHttpGet",
          "es:ESHttpDelete",
          "es:ESHttpHead"
        ]
        Resource = "${aws_opensearch_domain.main.arn}/*"
      },
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
          aws_dynamodb_table.search_index_metadata.arn,
          "${aws_dynamodb_table.search_index_metadata.arn}/index/*"
        ]
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
          aws_sqs_queue.search_indexing.arn,
          aws_sqs_queue.search_indexing_dlq.arn
        ]
      },
      {
        Effect = "Allow"
        Action = [
          "logs:CreateLogGroup",
          "logs:CreateLogStream",
          "logs:PutLogEvents"
        ]
        Resource = "arn:aws:logs:*:*:*"
      }
    ]
  })
}

resource "aws_iam_role_policy_attachment" "search_lambda_vpc" {
  role       = aws_iam_role.search_lambda.name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AWSLambdaVPCAccessExecutionRole"
}

# Lambda function for search indexing
resource "aws_lambda_function" "search_indexer" {
  filename         = data.archive_file.search_indexer.output_path
  function_name    = "${var.name_prefix}-search-indexer"
  role            = aws_iam_role.search_lambda.arn
  handler         = "search_indexer.handler"
  source_code_hash = data.archive_file.search_indexer.output_base64sha256
  runtime         = "python3.11"
  timeout         = 300
  memory_size     = 1024

  environment {
    variables = {
      OPENSEARCH_ENDPOINT = aws_opensearch_domain.main.endpoint
      METADATA_TABLE      = aws_dynamodb_table.search_index_metadata.name
      REDIS_ENDPOINT      = var.redis_endpoint
      BATCH_SIZE          = tostring(var.indexing_batch_size)
      MAX_RETRIES         = tostring(var.max_indexing_retries)
    }
  }

  vpc_config {
    subnet_ids         = var.subnet_ids
    security_group_ids = [aws_security_group.search_lambda.id]
  }

  reserved_concurrent_executions = var.lambda_concurrent_executions

  tags = var.tags

  depends_on = [
    aws_iam_role_policy_attachment.search_lambda_vpc,
    aws_cloudwatch_log_group.lambda_search_indexer
  ]
}

# Lambda function for search API
resource "aws_lambda_function" "search_api" {
  filename         = data.archive_file.search_api.output_path
  function_name    = "${var.name_prefix}-search-api"
  role            = aws_iam_role.search_lambda.arn
  handler         = "search_api.handler"
  source_code_hash = data.archive_file.search_api.output_base64sha256
  runtime         = "python3.11"
  timeout         = 30
  memory_size     = 512

  environment {
    variables = {
      OPENSEARCH_ENDPOINT = aws_opensearch_domain.main.endpoint
      REDIS_ENDPOINT      = var.redis_endpoint
      CACHE_TTL          = tostring(var.search_cache_ttl)
      MAX_RESULTS        = tostring(var.max_search_results)
      ENABLE_ANALYTICS   = tostring(var.enable_search_analytics)
    }
  }

  vpc_config {
    subnet_ids         = var.subnet_ids
    security_group_ids = [aws_security_group.search_lambda.id]
  }

  reserved_concurrent_executions = var.lambda_concurrent_executions

  tags = var.tags

  depends_on = [
    aws_iam_role_policy_attachment.search_lambda_vpc,
    aws_cloudwatch_log_group.lambda_search_api
  ]
}

# CloudWatch Log Groups for Lambda functions
resource "aws_cloudwatch_log_group" "lambda_search_indexer" {
  name              = "/aws/lambda/${var.name_prefix}-search-indexer"
  retention_in_days = var.log_retention_days

  tags = var.tags
}

resource "aws_cloudwatch_log_group" "lambda_search_api" {
  name              = "/aws/lambda/${var.name_prefix}-search-api"
  retention_in_days = var.log_retention_days

  tags = var.tags
}

# SQS event source mapping
resource "aws_lambda_event_source_mapping" "search_indexing" {
  event_source_arn = aws_sqs_queue.search_indexing.arn
  function_name    = aws_lambda_function.search_indexer.arn
  batch_size       = 10
  
  maximum_batching_window_in_seconds = 5

  depends_on = [aws_lambda_function.search_indexer]
}

# API Gateway for search API
resource "aws_apigatewayv2_api" "search_api" {
  name          = "${var.name_prefix}-search-api"
  protocol_type = "HTTP"
  description   = "Search API for social media platform"

  cors_configuration {
    allow_credentials = true
    allow_headers     = ["content-type", "authorization"]
    allow_methods     = ["GET", "POST", "OPTIONS"]
    allow_origins     = ["https://${var.domain_name}"]
    max_age          = 300
  }

  tags = var.tags
}

resource "aws_apigatewayv2_integration" "search_api" {
  api_id             = aws_apigatewayv2_api.search_api.id
  integration_type   = "AWS_PROXY"
  integration_method = "POST"
  integration_uri    = aws_lambda_function.search_api.invoke_arn
}

# Search API routes
resource "aws_apigatewayv2_route" "search" {
  api_id    = aws_apigatewayv2_api.search_api.id
  route_key = "GET /search"
  target    = "integrations/${aws_apigatewayv2_integration.search_api.id}"
}

resource "aws_apigatewayv2_route" "search_suggestions" {
  api_id    = aws_apigatewayv2_api.search_api.id
  route_key = "GET /suggest"
  target    = "integrations/${aws_apigatewayv2_integration.search_api.id}"
}

resource "aws_apigatewayv2_route" "search_analytics" {
  api_id    = aws_apigatewayv2_api.search_api.id
  route_key = "POST /analytics"
  target    = "integrations/${aws_apigatewayv2_integration.search_api.id}"
}

resource "aws_apigatewayv2_stage" "search_api" {
  api_id      = aws_apigatewayv2_api.search_api.id
  name        = var.environment
  auto_deploy = true

  access_log_settings {
    destination_arn = aws_cloudwatch_log_group.search_api.arn
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

resource "aws_lambda_permission" "allow_search_api_gateway" {
  statement_id  = "AllowExecutionFromAPIGateway"
  action        = "lambda:InvokeFunction"
  function_name = aws_lambda_function.search_api.function_name
  principal     = "apigateway.amazonaws.com"
  source_arn    = "${aws_apigatewayv2_api.search_api.execution_arn}/*/*"
}

# CloudWatch alarms for monitoring
resource "aws_cloudwatch_metric_alarm" "opensearch_cluster_status" {
  alarm_name          = "${var.name_prefix}-opensearch-cluster-status"
  comparison_operator = "LessThanThreshold"
  evaluation_periods  = "1"
  metric_name         = "ClusterStatus.yellow"
  namespace           = "AWS/ES"
  period              = "60"
  statistic           = "Maximum"
  threshold           = "1"
  alarm_description   = "OpenSearch cluster status is red"
  alarm_actions       = var.alarm_actions
  treat_missing_data  = "breaching"

  dimensions = {
    DomainName = aws_opensearch_domain.main.domain_name
    ClientId   = data.aws_caller_identity.current.account_id
  }

  tags = var.tags
}

resource "aws_cloudwatch_metric_alarm" "opensearch_cpu_utilization" {
  alarm_name          = "${var.name_prefix}-opensearch-cpu-high"
  comparison_operator = "GreaterThanThreshold"
  evaluation_periods  = "2"
  metric_name         = "CPUUtilization"
  namespace           = "AWS/ES"
  period              = "300"
  statistic           = "Average"
  threshold           = "80"
  alarm_description   = "OpenSearch CPU utilization is high"
  alarm_actions       = var.alarm_actions

  dimensions = {
    DomainName = aws_opensearch_domain.main.domain_name
    ClientId   = data.aws_caller_identity.current.account_id
  }

  tags = var.tags
}

resource "aws_cloudwatch_metric_alarm" "search_indexing_errors" {
  alarm_name          = "${var.name_prefix}-search-indexing-errors"
  comparison_operator = "GreaterThanThreshold"
  evaluation_periods  = "2"
  metric_name         = "Errors"
  namespace           = "AWS/Lambda"
  period              = "300"
  statistic           = "Sum"
  threshold           = "5"
  alarm_description   = "High error rate in search indexing"
  alarm_actions       = var.alarm_actions

  dimensions = {
    FunctionName = aws_lambda_function.search_indexer.function_name
  }

  tags = var.tags
}

# Lambda function packages
data "archive_file" "search_indexer" {
  type        = "zip"
  output_path = "/tmp/search_indexer.zip"
  source {
    content  = file("${path.module}/lambda/search_indexer.py")
    filename = "search_indexer.py"
  }
}

data "archive_file" "search_api" {
  type        = "zip"
  output_path = "/tmp/search_api.zip"
  source {
    content  = file("${path.module}/lambda/search_api.py")
    filename = "search_api.py"
  }
}

# Get current AWS account ID
data "aws_caller_identity" "current" {}