terraform {
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
  }
}

# Get current region and account info
data "aws_region" "current" {}
data "aws_caller_identity" "current" {}

# Regional certificate for API Gateway
resource "aws_acm_certificate" "regional" {
  domain_name               = "api.${var.domain_name}"
  subject_alternative_names = ["ws.${var.domain_name}", "*.api.${var.domain_name}"]
  validation_method         = "DNS"

  lifecycle {
    create_before_destroy = true
  }

  tags = var.tags
}

# API Gateway v2 for regional deployment
resource "aws_apigatewayv2_api" "regional" {
  name          = "${var.name_prefix}-regional-api"
  protocol_type = "HTTP"
  description   = "Regional API Gateway for ${var.region_name}"

  cors_configuration {
    allow_credentials = true
    allow_headers     = ["*"]
    allow_methods     = ["*"]
    allow_origins     = ["https://${var.domain_name}", "https://www.${var.domain_name}"]
    expose_headers    = ["*"]
    max_age          = 300
  }

  tags = var.tags
}

# Custom domain for regional API
resource "aws_apigatewayv2_domain_name" "regional" {
  domain_name = "api-${var.region_name}.${var.domain_name}"

  domain_name_configuration {
    certificate_arn = var.global_certificate_arn
    endpoint_type   = "REGIONAL"
    security_policy = "TLS_1_2"
  }

  tags = var.tags
}

# Integration with primary region
resource "aws_apigatewayv2_integration" "primary_proxy" {
  api_id             = aws_apigatewayv2_api.regional.id
  integration_type   = "HTTP_PROXY"
  integration_method = "ANY"
  integration_uri    = "https://${var.primary_api_endpoint}/{proxy}"
  
  request_parameters = {
    "overwrite:header.Host"           = var.primary_api_endpoint
    "append:header.X-Forwarded-For"  = "$context.identity.sourceIp"
    "append:header.X-Region"         = var.region_name
  }
}

# Routes for API traffic
resource "aws_apigatewayv2_route" "default" {
  api_id    = aws_apigatewayv2_api.regional.id
  route_key = "ANY /{proxy+}"
  target    = "integrations/${aws_apigatewayv2_integration.primary_proxy.id}"
}

resource "aws_apigatewayv2_route" "root" {
  api_id    = aws_apigatewayv2_api.regional.id
  route_key = "ANY /"
  target    = "integrations/${aws_apigatewayv2_integration.primary_proxy.id}"
}

# Health check route for monitoring
resource "aws_apigatewayv2_route" "health" {
  api_id    = aws_apigatewayv2_api.regional.id
  route_key = "GET /health"
  target    = "integrations/${aws_apigatewayv2_integration.health_check.id}"
}

# Health check integration (local response)
resource "aws_apigatewayv2_integration" "health_check" {
  api_id           = aws_apigatewayv2_api.regional.id
  integration_type = "MOCK"
  
  request_templates = {
    "application/json" = jsonencode({
      statusCode = 200
    })
  }
  
  template_selection_expression = "200"
}

# Stage for regional API
resource "aws_apigatewayv2_stage" "regional" {
  api_id      = aws_apigatewayv2_api.regional.id
  name        = "v1"
  auto_deploy = true

  # Access logging
  access_log_settings {
    destination_arn = aws_cloudwatch_log_group.api_gateway.arn
    format = jsonencode({
      requestId       = "$context.requestId"
      ip              = "$context.identity.sourceIp"
      requestTime     = "$context.requestTime"
      httpMethod      = "$context.httpMethod"
      routeKey        = "$context.routeKey"
      status          = "$context.status"
      protocol        = "$context.protocol"
      responseLength  = "$context.responseLength"
      responseTime    = "$context.responseTime"
      integrationLatency = "$context.integrationLatency"
      region          = var.region_name
    })
  }

  # Default route settings
  default_route_settings {
    detailed_metrics_enabled = true
    throttling_burst_limit   = 5000
    throttling_rate_limit    = 2000
  }

  tags = var.tags
}

# API mapping
resource "aws_apigatewayv2_api_mapping" "regional" {
  api_id      = aws_apigatewayv2_api.regional.id
  domain_name = aws_apigatewayv2_domain_name.regional.id
  stage       = aws_apigatewayv2_stage.regional.id
}

# CloudWatch Log Group for API Gateway
resource "aws_cloudwatch_log_group" "api_gateway" {
  name              = "/aws/apigateway/${var.name_prefix}/regional"
  retention_in_days = 14

  tags = merge(var.tags, {
    Name = "${var.name_prefix}-regional-api-logs"
  })
}

# Regional WAF for additional protection
resource "aws_wafv2_web_acl" "regional" {
  name  = "${var.name_prefix}-regional-waf"
  scope = "REGIONAL"

  default_action {
    allow {}
  }

  # Rate limiting for regional traffic
  rule {
    name     = "RegionalRateLimitRule"
    priority = 1

    action {
      block {}
    }

    statement {
      rate_based_statement {
        limit              = 1000
        aggregate_key_type = "IP"
      }
    }

    visibility_config {
      cloudwatch_metrics_enabled = true
      metric_name                = "${var.name_prefix}-RegionalRateLimit"
      sampled_requests_enabled   = true
    }
  }

  # Geographic filtering (optional)
  dynamic "rule" {
    for_each = var.allowed_countries != null ? [1] : []
    content {
      name     = "GeoFilter"
      priority = 2

      action {
        block {}
      }

      statement {
        geo_match_statement {
          country_codes = var.blocked_countries
        }
      }

      visibility_config {
        cloudwatch_metrics_enabled = true
        metric_name                = "${var.name_prefix}-GeoFilter"
        sampled_requests_enabled   = true
      }
    }
  }

  visibility_config {
    cloudwatch_metrics_enabled = true
    metric_name                = "${var.name_prefix}-RegionalWAF"
    sampled_requests_enabled   = true
  }

  tags = var.tags
}

# Associate WAF with API Gateway
resource "aws_wafv2_web_acl_association" "regional" {
  resource_arn = aws_apigatewayv2_stage.regional.arn
  web_acl_arn  = aws_wafv2_web_acl.regional.arn
}

# CloudWatch Alarms for regional monitoring
resource "aws_cloudwatch_metric_alarm" "regional_api_errors" {
  alarm_name          = "${var.name_prefix}-regional-api-errors"
  comparison_operator = "GreaterThanThreshold"
  evaluation_periods  = "2"
  metric_name         = "4XXError"
  namespace           = "AWS/ApiGatewayV2"
  period              = "300"
  statistic           = "Sum"
  threshold           = "50"
  alarm_description   = "Regional API Gateway 4XX errors"
  treat_missing_data  = "notBreaching"

  dimensions = {
    ApiId = aws_apigatewayv2_api.regional.id
    Stage = aws_apigatewayv2_stage.regional.name
  }

  tags = var.tags
}

resource "aws_cloudwatch_metric_alarm" "regional_api_latency" {
  alarm_name          = "${var.name_prefix}-regional-api-latency"
  comparison_operator = "GreaterThanThreshold"
  evaluation_periods  = "2"
  metric_name         = "IntegrationLatency"
  namespace           = "AWS/ApiGatewayV2"
  period              = "300"
  statistic           = "Average"
  threshold           = "5000"
  alarm_description   = "Regional API Gateway high latency"
  treat_missing_data  = "notBreaching"

  dimensions = {
    ApiId = aws_apigatewayv2_api.regional.id
    Stage = aws_apigatewayv2_stage.regional.name
  }

  tags = var.tags
}

# CloudWatch Dashboard for regional monitoring
resource "aws_cloudwatch_dashboard" "regional" {
  dashboard_name = "${var.name_prefix}-regional-${var.region_name}"

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
            ["AWS/ApiGatewayV2", "Count", "ApiId", aws_apigatewayv2_api.regional.id, "Stage", aws_apigatewayv2_stage.regional.name],
            [".", "IntegrationLatency", ".", ".", ".", "."],
            [".", "4XXError", ".", ".", ".", "."],
            [".", "5XXError", ".", ".", ".", "."]
          ]
          period = 300
          stat   = "Sum"
          region = var.region_name
          title  = "Regional API Gateway Metrics - ${var.region_name}"
          yAxis = {
            left = {
              min = 0
            }
          }
        }
      },
      {
        type   = "log"
        x      = 0
        y      = 6
        width  = 24
        height = 6

        properties = {
          query   = "SOURCE '${aws_cloudwatch_log_group.api_gateway.name}' | fields @timestamp, @message\n| filter @message like /ERROR/\n| sort @timestamp desc\n| limit 100"
          region  = var.region_name
          title   = "Regional API Gateway Errors - ${var.region_name}"
        }
      }
    ]
  })
}
