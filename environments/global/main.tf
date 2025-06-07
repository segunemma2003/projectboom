terraform {
  required_version = ">= 1.0"
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
  }
}

# Primary provider (EU West 1)
provider "aws" {
  alias  = "eu_west_1"
  region = "eu-west-1"
  
  default_tags {
    tags = local.common_tags
  }
}

# US East 1 provider (for CloudFront certificates)
provider "aws" {
  alias  = "us_east_1"
  region = "us-east-1"
  
  default_tags {
    tags = local.common_tags
  }
}

# Asia Pacific provider
provider "aws" {
  alias  = "ap_southeast_1"
  region = "ap-southeast-1"
  
  default_tags {
    tags = local.common_tags
  }
}

# Data sources
data "aws_caller_identity" "current" {}
data "aws_regions" "available" {}

# Local values
locals {
  common_tags = {
    Project     = var.project_name
    Environment = "global"
    ManagedBy   = "terraform"
    Owner       = "platform-team"
  }
  
  # Primary region configuration
  primary_region = "eu-west-1"
  
  # Regional endpoints
  regional_endpoints = {
    eu_west_1      = "api-eu.${var.domain_name}"
    us_east_1      = "api-us.${var.domain_name}"
    ap_southeast_1 = "api-ap.${var.domain_name}"
  }
}

# Route 53 Hosted Zone (assuming it exists)
data "aws_route53_zone" "main" {
  name         = var.domain_name
  private_zone = false
}

# Global CloudFront certificate (must be in us-east-1)
resource "aws_acm_certificate" "cloudfront" {
  provider = aws.us_east_1
  
  domain_name               = var.domain_name
  subject_alternative_names = ["*.${var.domain_name}"]
  validation_method         = "DNS"

  lifecycle {
    create_before_destroy = true
  }

  tags = local.common_tags
}

# Certificate validation
resource "aws_route53_record" "cloudfront_cert_validation" {
  provider = aws.us_east_1
  
  for_each = {
    for dvo in aws_acm_certificate.cloudfront.domain_validation_options : dvo.domain_name => {
      name   = dvo.resource_record_name
      record = dvo.resource_record_value
      type   = dvo.resource_record_type
    }
  }

  allow_overwrite = true
  name            = each.value.name
  records         = [each.value.record]
  ttl             = 60
  type            = each.value.type
  zone_id         = data.aws_route53_zone.main.zone_id
}

resource "aws_acm_certificate_validation" "cloudfront" {
  provider = aws.us_east_1
  
  certificate_arn         = aws_acm_certificate.cloudfront.arn
  validation_record_fqdns = [for record in aws_route53_record.cloudfront_cert_validation : record.fqdn]
}

# Global CloudFront Distribution
resource "aws_cloudfront_distribution" "global" {
  origin {
    domain_name = var.primary_alb_dns_name
    origin_id   = "primary-alb"

    custom_origin_config {
      http_port              = 80
      https_port             = 443
      origin_protocol_policy = "https-only"
      origin_ssl_protocols   = ["TLSv1.2"]
    }
  }

  # Additional origins for regional APIs
  dynamic "origin" {
    for_each = var.regional_endpoints
    content {
      domain_name = origin.value
      origin_id   = "api-${origin.key}"

      custom_origin_config {
        http_port              = 80
        https_port             = 443
        origin_protocol_policy = "https-only"
        origin_ssl_protocols   = ["TLSv1.2"]
      }
    }
  }

  enabled             = true
  is_ipv6_enabled     = true
  default_root_object = "index.html"
  price_class         = "PriceClass_All"

  aliases = [var.domain_name, "www.${var.domain_name}", "cdn.${var.domain_name}"]

  # Default cache behavior (primary region)
  default_cache_behavior {
    allowed_methods        = ["DELETE", "GET", "HEAD", "OPTIONS", "PATCH", "POST", "PUT"]
    cached_methods         = ["GET", "HEAD"]
    target_origin_id       = "primary-alb"
    compress               = true
    viewer_protocol_policy = "redirect-to-https"

    forwarded_values {
      query_string = true
      headers      = ["Host", "Authorization", "CloudFront-Forwarded-Proto", "CloudFront-Viewer-Country"]

      cookies {
        forward = "all"
      }
    }

    min_ttl     = 0
    default_ttl = 3600
    max_ttl     = 86400

    # Lambda@Edge for geographical routing
    dynamic "lambda_function_association" {
      for_each = var.enable_edge_routing ? [1] : []
      content {
        event_type   = "origin-request"
        lambda_arn   = aws_lambda_function.edge_router[0].qualified_arn
        include_body = false
      }
    }
  }

  # API cache behavior with geographical routing
  ordered_cache_behavior {
    path_pattern     = "/api/*"
    allowed_methods  = ["DELETE", "GET", "HEAD", "OPTIONS", "PATCH", "POST", "PUT"]
    cached_methods   = ["GET", "HEAD", "OPTIONS"]
    target_origin_id = "primary-alb"
    compress         = true

    forwarded_values {
      query_string = true
      headers      = ["*"]

      cookies {
        forward = "all"
      }
    }

    viewer_protocol_policy = "redirect-to-https"
    min_ttl                = 0
    default_ttl            = 0
    max_ttl                = 300

    # Edge routing for API requests
    dynamic "lambda_function_association" {
      for_each = var.enable_edge_routing ? [1] : []
      content {
        event_type   = "origin-request"
        lambda_arn   = aws_lambda_function.edge_router[0].qualified_arn
        include_body = false
      }
    }
  }

  # Static content cache behavior
  ordered_cache_behavior {
    path_pattern     = "/static/*"
    allowed_methods  = ["GET", "HEAD"]
    cached_methods   = ["GET", "HEAD"]
    target_origin_id = "primary-alb"
    compress         = true

    forwarded_values {
      query_string = false
      cookies {
        forward = "none"
      }
    }

    viewer_protocol_policy = "redirect-to-https"
    min_ttl                = 86400
    default_ttl            = 86400
    max_ttl                = 31536000
  }

  # Media files cache behavior
  ordered_cache_behavior {
    path_pattern     = "/media/*"
    allowed_methods  = ["GET", "HEAD"]
    cached_methods   = ["GET", "HEAD"]
    target_origin_id = "primary-alb"
    compress         = true

    forwarded_values {
      query_string = false
      cookies {
        forward = "none"
      }
    }

    viewer_protocol_policy = "redirect-to-https"
    min_ttl                = 86400
    default_ttl            = 604800
    max_ttl                = 31536000
  }

  restrictions {
    geo_restriction {
      restriction_type = "none"
    }
  }

  viewer_certificate {
    acm_certificate_arn      = aws_acm_certificate_validation.cloudfront.certificate_arn
    ssl_support_method       = "sni-only"
    minimum_protocol_version = "TLSv1.2_2021"
  }

  web_acl_id = aws_wafv2_web_acl.global.arn

  tags = local.common_tags
}

# Global WAF for CloudFront
resource "aws_wafv2_web_acl" "global" {
  name  = "${var.project_name}-global-waf"
  scope = "CLOUDFRONT"

  default_action {
    allow {}
  }

  # Rate limiting rule
  rule {
    name     = "GlobalRateLimitRule"
    priority = 1

    action {
      block {}
    }

    statement {
      rate_based_statement {
        limit              = var.global_rate_limit
        aggregate_key_type = "IP"
      }
    }

    visibility_config {
      cloudwatch_metrics_enabled = true
      metric_name                = "GlobalRateLimit"
      sampled_requests_enabled   = true
    }
  }

  # AWS Managed Core Rule Set
  rule {
    name     = "AWSManagedRulesCommonRuleSet"
    priority = 2

    # FIXED: Changed from action { allow {} } to override_action
    override_action {
      none {}
    }

    statement {
      managed_rule_group_statement {
        name        = "AWSManagedRulesCommonRuleSet"
        vendor_name = "AWS"
      }
    }

    visibility_config {
      cloudwatch_metrics_enabled = true
      metric_name                = "CommonRuleSet"
      sampled_requests_enabled   = true
    }
  }

  # Known Bad Inputs Rule Set
  rule {
    name     = "AWSManagedRulesKnownBadInputsRuleSet"
    priority = 3

    # FIXED: Changed from action { allow {} } to override_action
    override_action {
      none {}
    }

    statement {
      managed_rule_group_statement {
        name        = "AWSManagedRulesKnownBadInputsRuleSet"
        vendor_name = "AWS"
      }
    }

    visibility_config {
      cloudwatch_metrics_enabled = true
      metric_name                = "KnownBadInputs"
      sampled_requests_enabled   = true
    }
  }

  # SQL Injection Rule Set
  rule {
    name     = "AWSManagedRulesSQLiRuleSet"
    priority = 4

    override_action {
      none {}
    }

    statement {
      managed_rule_group_statement {
        name        = "AWSManagedRulesSQLiRuleSet"
        vendor_name = "AWS"
      }
    }

    visibility_config {
      cloudwatch_metrics_enabled = true
      metric_name                = "SQLiRuleSet"
      sampled_requests_enabled   = true
    }
  }

  visibility_config {
    cloudwatch_metrics_enabled = true
    metric_name                = "GlobalWAF"
    sampled_requests_enabled   = true
  }

  tags = local.common_tags
}

# Lambda@Edge function for geographical routing
resource "aws_lambda_function" "edge_router" {
  count = var.enable_edge_routing ? 1 : 0
  
  provider = aws.us_east_1  # Lambda@Edge must be in us-east-1
  
  filename         = data.archive_file.edge_router[0].output_path
  function_name    = "${var.project_name}-edge-router"
  role            = aws_iam_role.edge_router[0].arn
  handler         = "lambda_function.lambda_handler"
  source_code_hash = data.archive_file.edge_router[0].output_base64sha256
  runtime         = "python3.11"
  timeout         = 5
  publish         = true

  tags = local.common_tags
}

data "archive_file" "edge_router" {
  count = var.enable_edge_routing ? 1 : 0
  
  type        = "zip"
  output_path = "/tmp/edge_router.zip"
  source {
    content = templatefile("${path.module}/lambda/edge_router.py", {
      regional_endpoints = jsonencode(local.regional_endpoints)
    })
    filename = "lambda_function.py"
  }
}

# IAM role for Lambda@Edge
resource "aws_iam_role" "edge_router" {
  count = var.enable_edge_routing ? 1 : 0
  
  provider = aws.us_east_1
  
  name = "${var.project_name}-edge-router-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action = "sts:AssumeRole"
        Effect = "Allow"
        Principal = {
          Service = ["lambda.amazonaws.com", "edgelambda.amazonaws.com"]
        }
      }
    ]
  })

  tags = local.common_tags
}

resource "aws_iam_role_policy_attachment" "edge_router" {
  count = var.enable_edge_routing ? 1 : 0
  
  provider = aws.us_east_1
  
  role       = aws_iam_role.edge_router[0].name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AWSLambdaBasicExecutionRole"
}

# Regional API Gateways
module "regional_api_us_east" {
  source = "../../modules/regional_api"
  
  providers = {
    aws = aws.us_east_1
  }
  
  name_prefix             = "${var.project_name}-us-east"
  region_name            = "us-east-1"
  domain_name            = var.domain_name
  primary_api_endpoint   = var.primary_api_endpoint
  global_certificate_arn = aws_acm_certificate_validation.cloudfront.certificate_arn
  
  tags = local.common_tags
}

module "regional_api_ap_southeast" {
  source = "../../modules/regional_api"
  
  providers = {
    aws = aws.ap_southeast_1
  }
  
  name_prefix             = "${var.project_name}-ap-southeast"
  region_name            = "ap-southeast-1"
  domain_name            = var.domain_name
  primary_api_endpoint   = var.primary_api_endpoint
  global_certificate_arn = aws_acm_certificate_validation.cloudfront.certificate_arn
  
  tags = local.common_tags
}

# Route 53 Health Checks
resource "aws_route53_health_check" "primary" {
  fqdn                            = var.primary_api_endpoint
  port                            = 443
  type                            = "HTTPS"
  resource_path                   = "/health/"
  failure_threshold               = "3"
  request_interval                = "30"
  cloudwatch_alarm_region         = local.primary_region
  cloudwatch_alarm_name           = "${var.project_name}-primary-health"
  insufficient_data_health_status = "Failure"

  tags = merge(local.common_tags, {
    Name = "${var.project_name}-primary-health-check"
  })
}

resource "aws_route53_health_check" "us_east" {
  fqdn                            = module.regional_api_us_east.api_gateway_domain
  port                            = 443
  type                            = "HTTPS"
  resource_path                   = "/health/"
  failure_threshold               = "3"
  request_interval                = "30"
  cloudwatch_alarm_region         = "us-east-1"
  cloudwatch_alarm_name           = "${var.project_name}-us-east-health"
  insufficient_data_health_status = "Failure"

  tags = merge(local.common_tags, {
    Name = "${var.project_name}-us-east-health-check"
  })
}

# Route 53 DNS Records with health check routing
resource "aws_route53_record" "primary" {
  zone_id = data.aws_route53_zone.main.zone_id
  name    = var.domain_name
  type    = "A"

  alias {
    name                   = aws_cloudfront_distribution.global.domain_name
    zone_id                = aws_cloudfront_distribution.global.hosted_zone_id
    evaluate_target_health = false
  }
}

# CloudWatch Dashboard for global monitoring
resource "aws_cloudwatch_dashboard" "global" {
  dashboard_name = "${var.project_name}-global-overview"

  dashboard_body = jsonencode({
    widgets = [
      {
        type   = "metric"
        x      = 0
        y      = 0
        width  = 12
        height = 6

        properties = {
          metrics = [
            ["AWS/CloudFront", "Requests", "DistributionId", aws_cloudfront_distribution.global.id],
            [".", "BytesDownloaded", ".", "."],
            [".", "4xxErrorRate", ".", "."],
            [".", "5xxErrorRate", ".", "."]
          ]
          period = 300
          stat   = "Sum"
          region = "us-east-1"
          title  = "Global CloudFront Metrics"
          yAxis = {
            left = {
              min = 0
            }
          }
        }
      },
      {
        type   = "metric"
        x      = 12
        y      = 0
        width  = 12
        height = 6

        properties = {
          metrics = [
            ["AWS/Route53", "HealthCheckStatus", "HealthCheckId", aws_route53_health_check.primary.id],
            [".", ".", ".", aws_route53_health_check.us_east.id]
          ]
          period = 300
          stat   = "Average"
          region = "us-east-1"
          title  = "Regional Health Checks"
          yAxis = {
            left = {
              min = 0
              max = 1
            }
          }
        }
      },
      {
        type   = "metric"
        x      = 0
        y      = 6
        width  = 24
        height = 6

        properties = {
          metrics = [
            # FIXED: Updated WAF metrics syntax
            ["AWS/WAFV2", "AllowedRequests", "WebACL", aws_wafv2_web_acl.global.name, "Region", "CloudFront", "Rule", "ALL"],
            [".", "BlockedRequests", ".", ".", ".", ".", ".", "."]
          ]
          period = 300
          stat   = "Sum"
          region = "us-east-1"
          title  = "Global WAF Activity"
        }
      }
    ]
  })
}

# SNS Topic for global alerts
resource "aws_sns_topic" "global_alerts" {
  name = "${var.project_name}-global-alerts"
  tags = local.common_tags
}

resource "aws_sns_topic_subscription" "global_email_alerts" {
  count     = length(var.global_alert_emails)
  topic_arn = aws_sns_topic.global_alerts.arn
  protocol  = "email"
  endpoint  = var.global_alert_emails[count.index]
}

# CloudWatch Alarms for global infrastructure
resource "aws_cloudwatch_metric_alarm" "cloudfront_error_rate" {
  alarm_name          = "${var.project_name}-cloudfront-high-error-rate"
  comparison_operator = "GreaterThanThreshold"
  evaluation_periods  = "2"
  metric_name         = "4xxErrorRate"
  namespace           = "AWS/CloudFront"
  period              = "300"
  statistic           = "Average"
  threshold           = "5"
  alarm_description   = "CloudFront 4xx error rate is high"
  alarm_actions       = [aws_sns_topic.global_alerts.arn]
  treat_missing_data  = "notBreaching"

  dimensions = {
    DistributionId = aws_cloudfront_distribution.global.id
  }

  tags = local.common_tags
}

resource "aws_cloudwatch_metric_alarm" "primary_health_check" {
  alarm_name          = "${var.project_name}-primary-region-down"
  comparison_operator = "LessThanThreshold"
  evaluation_periods  = "2"
  metric_name         = "HealthCheckStatus"
  namespace           = "AWS/Route53"
  period              = "60"
  statistic           = "Minimum"
  threshold           = "1"
  alarm_description   = "Primary region health check failed"
  alarm_actions       = [aws_sns_topic.global_alerts.arn]
  treat_missing_data  = "breaching"

  dimensions = {
    HealthCheckId = aws_route53_health_check.primary.id
  }

  tags = local.common_tags
}

# Global backup and disaster recovery configuration
resource "aws_backup_plan" "global" {
  name = "${var.project_name}-global-backup"

  rule {
    rule_name         = "daily_backups"
    target_vault_name = aws_backup_vault.global.name
    schedule          = "cron(0 3 ? * * *)"  # Daily at 3 AM UTC

    lifecycle {
      cold_storage_after = 30
      delete_after       = 365
    }

    recovery_point_tags = local.common_tags
  }

  tags = local.common_tags
}

resource "aws_backup_vault" "global" {
  name        = "${var.project_name}-global-backup-vault"
  kms_key_arn = aws_kms_key.backup.arn
  tags        = local.common_tags
}

resource "aws_kms_key" "backup" {
  description             = "KMS key for global backups"
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
        Sid    = "Allow backup service"
        Effect = "Allow"
        Principal = {
          Service = "backup.amazonaws.com"
        }
        Action = [
          "kms:Decrypt",
          "kms:GenerateDataKey"
        ]
        Resource = "*"
      }
    ]
  })

  tags = local.common_tags
}

resource "aws_kms_alias" "backup" {
  name          = "alias/${var.project_name}-global-backup"
  target_key_id = aws_kms_key.backup.key_id
}

# Cross-region replication for critical data
resource "aws_s3_bucket" "global_replication" {
  provider = aws.us_east_1
  bucket   = "${var.project_name}-global-replication-${random_id.bucket_suffix.hex}"
  tags     = local.common_tags
}

resource "random_id" "bucket_suffix" {
  byte_length = 4
}

resource "aws_s3_bucket_versioning" "global_replication" {
  provider = aws.us_east_1
  bucket   = aws_s3_bucket.global_replication.id
  versioning_configuration {
    status = "Enabled"
  }
}

resource "aws_s3_bucket_server_side_encryption_configuration" "global_replication" {
  provider = aws.us_east_1
  bucket   = aws_s3_bucket.global_replication.id

  rule {
    apply_server_side_encryption_by_default {
      sse_algorithm = "AES256"
    }
  }
}

# Cost management for global resources
resource "aws_budgets_budget" "global_budget" {
  name         = "${var.project_name}-global-budget"
  budget_type  = "COST"
  limit_amount = var.global_monthly_budget_limit
  limit_unit   = "USD"
  time_unit    = "MONTHLY"
  
  # Simplified - no cost filters
  notification {
    comparison_operator        = "GREATER_THAN"
    threshold                 = 80
    threshold_type            = "PERCENTAGE"
    notification_type          = "ACTUAL"
    subscriber_email_addresses = var.global_alert_emails
  }

  tags = local.common_tags
}

# Alternative with working cost filter syntax (AWS Provider 5.x)
resource "aws_budgets_budget" "global_budget_with_filter" {
  count = 0  # Set to 1 to enable this version instead
  
  name         = "${var.project_name}-global-budget"
  budget_type  = "COST"
  limit_amount = var.global_monthly_budget_limit
  limit_unit   = "USD"
  time_unit    = "MONTHLY"
  
  time_period_start = formatdate("YYYY-MM-01_00:00", timestamp())
  
  # Working syntax for AWS Provider 5.x
  cost_filter {
    name   = "Service"
    values = ["Amazon CloudFront", "Amazon Route 53", "AWS WAF"]
  }

  notification {
    comparison_operator        = "GREATER_THAN"
    threshold                 = 80
    threshold_type            = "PERCENTAGE"
    notification_type          = "ACTUAL"
    subscriber_email_addresses = var.global_alert_emails
  }

  tags = local.common_tags
}