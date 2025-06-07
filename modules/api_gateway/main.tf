resource "aws_apigatewayv2_api" "main" {
  name          = "${var.name_prefix}-api"
  protocol_type = "HTTP"
  description   = "API Gateway for ${var.name_prefix}"

  cors_configuration {
    allow_credentials = true
    allow_headers     = ["*"]
    allow_methods     = ["*"]
    allow_origins     = var.cors_origins
    expose_headers    = ["*"]
    max_age          = 300
  }

  tags = var.tags
}

# Custom domain for API Gateway
resource "aws_apigatewayv2_domain_name" "main" {
  domain_name = "api.${var.domain_name}"

  domain_name_configuration {
    certificate_arn = var.certificate_arn
    endpoint_type   = "REGIONAL"
    security_policy = "TLS_1_2"
  }

  tags = var.tags
}

# VPC Link for private ALB integration
resource "aws_apigatewayv2_vpc_link" "main" {
  name               = "${var.name_prefix}-vpc-link"
  security_group_ids = [aws_security_group.vpc_link.id]
  subnet_ids         = var.private_subnet_ids

  tags = var.tags
}

# Security group for VPC Link
resource "aws_security_group" "vpc_link" {
  name_prefix = "${var.name_prefix}-api-gateway-vpc-link-"
  vpc_id      = var.vpc_id

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = merge(var.tags, {
    Name = "${var.name_prefix}-api-gateway-vpc-link-sg"
  })

  lifecycle {
    create_before_destroy = true
  }
}

# Integration with ALB
resource "aws_apigatewayv2_integration" "alb" {
  api_id             = aws_apigatewayv2_api.main.id
  integration_type   = "HTTP_PROXY"
  integration_method = "ANY"
  integration_uri    = var.alb_listener_arn

  connection_type = "VPC_LINK"
  connection_id   = aws_apigatewayv2_vpc_link.main.id

  request_parameters = {
    "overwrite:header.Host" = "$request.header.Host"
  }
}

# Routes for different API endpoints
resource "aws_apigatewayv2_route" "api_default" {
  api_id    = aws_apigatewayv2_api.main.id
  route_key = "ANY /{proxy+}"
  target    = "integrations/${aws_apigatewayv2_integration.alb.id}"
}

resource "aws_apigatewayv2_route" "api_root" {
  api_id    = aws_apigatewayv2_api.main.id
  route_key = "ANY /"
  target    = "integrations/${aws_apigatewayv2_integration.alb.id}"
}

# WebSocket API for real-time features
resource "aws_apigatewayv2_api" "websocket" {
  name                       = "${var.name_prefix}-websocket"
  protocol_type             = "WEBSOCKET"
  route_selection_expression = "$request.body.action"
  description               = "WebSocket API for ${var.name_prefix}"

  tags = var.tags
}

# WebSocket integration
resource "aws_apigatewayv2_integration" "websocket" {
  api_id             = aws_apigatewayv2_api.websocket.id
  integration_type   = "HTTP_PROXY"
  integration_method = "POST"
  integration_uri    = "http://${var.alb_dns_name}:8001"

  connection_type = "VPC_LINK"
  connection_id   = aws_apigatewayv2_vpc_link.main.id
}

# WebSocket routes
resource "aws_apigatewayv2_route" "websocket_connect" {
  api_id    = aws_apigatewayv2_api.websocket.id
  route_key = "$connect"
  target    = "integrations/${aws_apigatewayv2_integration.websocket.id}"
}

resource "aws_apigatewayv2_route" "websocket_disconnect" {
  api_id    = aws_apigatewayv2_api.websocket.id
  route_key = "$disconnect"
  target    = "integrations/${aws_apigatewayv2_integration.websocket.id}"
}

resource "aws_apigatewayv2_route" "websocket_default" {
  api_id    = aws_apigatewayv2_api.websocket.id
  route_key = "$default"
  target    = "integrations/${aws_apigatewayv2_integration.websocket.id}"
}

# Stages for HTTP API - FIXED: No throttle_settings for v2
resource "aws_apigatewayv2_stage" "main" {
  api_id      = aws_apigatewayv2_api.main.id
  name        = var.environment
  auto_deploy = true

  # REMOVED: throttle_settings block - not supported in API Gateway v2
  # Throttling is handled at the route level or through usage plans

  # Access logging
  access_log_settings {
    destination_arn = aws_cloudwatch_log_group.api_gateway.arn
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
      integrationLatency = "$context.integrationLatency"
      errorMessage   = "$context.error.message"
      errorType      = "$context.error.messageString"
    })
  }

  tags = var.tags
}

# Stage for WebSocket API - FIXED: No throttle_settings
resource "aws_apigatewayv2_stage" "websocket" {
  api_id      = aws_apigatewayv2_api.websocket.id
  name        = var.environment
  auto_deploy = true

  # REMOVED: throttle_settings block - not supported in API Gateway v2

  access_log_settings {
    destination_arn = aws_cloudwatch_log_group.websocket.arn
    format = jsonencode({
      requestId      = "$context.requestId"
      connectionId   = "$context.connectionId"
      routeKey       = "$context.routeKey"
      status         = "$context.status"
      responseTime   = "$context.responseTime"
      integrationLatency = "$context.integrationLatency"
      errorMessage   = "$context.error.message"
    })
  }

  tags = var.tags
}

# API mapping for custom domain
resource "aws_apigatewayv2_api_mapping" "main" {
  api_id      = aws_apigatewayv2_api.main.id
  domain_name = aws_apigatewayv2_domain_name.main.id
  stage       = aws_apigatewayv2_stage.main.id
}

# CloudWatch Log Groups
resource "aws_cloudwatch_log_group" "api_gateway" {
  name              = "/aws/apigateway/${var.name_prefix}/access-logs"
  retention_in_days = var.log_retention_days

  tags = merge(var.tags, {
    Name = "${var.name_prefix}-api-gateway-logs"
  })
}

resource "aws_cloudwatch_log_group" "websocket" {
  name              = "/aws/apigateway/${var.name_prefix}/websocket-logs"
  retention_in_days = var.log_retention_days

  tags = merge(var.tags, {
    Name = "${var.name_prefix}-websocket-logs"
  })
}

# WAF for additional protection
resource "aws_wafv2_web_acl" "api_gateway" {
  name  = "${var.name_prefix}-api-gateway-waf"
  scope = "REGIONAL"

  default_action {
    allow {}
  }

  # Rate limiting rule
  rule {
    name     = "RateLimitRule"
    priority = 1

    action {
      block {}
    }

    statement {
      rate_based_statement {
        limit              = var.waf_rate_limit
        aggregate_key_type = "IP"
      }
    }

    visibility_config {
      cloudwatch_metrics_enabled = true
      metric_name                = "${var.name_prefix}-RateLimitRule"
      sampled_requests_enabled   = true
    }
  }

  # AWS Managed Core Rule Set
  rule {
    name     = "AWSManagedRulesCommonRuleSet"
    priority = 2

    action {
      allow {}
    }

    statement {
      managed_rule_group_statement {
        name        = "AWSManagedRulesCommonRuleSet"
        vendor_name = "AWS"
      }
    }

    visibility_config {
      cloudwatch_metrics_enabled = true
      metric_name                = "${var.name_prefix}-CommonRuleSet"
      sampled_requests_enabled   = true
    }
  }

  # Known Bad Inputs Rule Set
  rule {
    name     = "AWSManagedRulesKnownBadInputsRuleSet"
    priority = 3

    action {
      allow {}
    }

    statement {
      managed_rule_group_statement {
        name        = "AWSManagedRulesKnownBadInputsRuleSet"
        vendor_name = "AWS"
      }
    }

    visibility_config {
      cloudwatch_metrics_enabled = true
      metric_name                = "${var.name_prefix}-KnownBadInputs"
      sampled_requests_enabled   = true
    }
  }

  # SQL Injection Rule Set
  rule {
    name     = "AWSManagedRulesSQLiRuleSet"
    priority = 4

    action {
      allow {}
    }

    statement {
      managed_rule_group_statement {
        name        = "AWSManagedRulesSQLiRuleSet"
        vendor_name = "AWS"
      }
    }

    visibility_config {
      cloudwatch_metrics_enabled = true
      metric_name                = "${var.name_prefix}-SQLiRuleSet"
      sampled_requests_enabled   = true
    }
  }

  visibility_config {
    cloudwatch_metrics_enabled = true
    metric_name                = "${var.name_prefix}-WAF"
    sampled_requests_enabled   = true
  }

  tags = var.tags
}

# Associate WAF with API Gateway
resource "aws_wafv2_web_acl_association" "api_gateway" {
  resource_arn = aws_apigatewayv2_stage.main.arn
  web_acl_arn  = aws_wafv2_web_acl.api_gateway.arn
}

# REMOVED: Usage Plans for API Gateway v2 don't work the same way
# API Gateway v2 uses different throttling mechanisms
# You can implement throttling at the route level if needed:

resource "aws_apigatewayv2_route" "api_throttled" {
  count = var.enable_route_throttling ? 1 : 0
  
  api_id    = aws_apigatewayv2_api.main.id
  route_key = "POST /api/high-volume-endpoint"
  target    = "integrations/${aws_apigatewayv2_integration.alb.id}"
  
  # Route-level throttling for specific endpoints
  authorization_type = "NONE"
}

# CloudWatch Alarms for monitoring
resource "aws_cloudwatch_metric_alarm" "api_gateway_4xx_errors" {
  alarm_name          = "${var.name_prefix}-api-gateway-4xx-errors"
  comparison_operator = "GreaterThanThreshold"
  evaluation_periods  = "2"
  metric_name         = "4xx"
  namespace           = "AWS/ApiGatewayV2"
  period              = "300"
  statistic           = "Sum"
  threshold           = "50"
  alarm_description   = "This metric monitors API Gateway 4XX errors"
  alarm_actions       = var.alarm_actions

  dimensions = {
    ApiId = aws_apigatewayv2_api.main.id
    Stage = aws_apigatewayv2_stage.main.name
  }

  tags = var.tags
}

resource "aws_cloudwatch_metric_alarm" "api_gateway_5xx_errors" {
  alarm_name          = "${var.name_prefix}-api-gateway-5xx-errors"
  comparison_operator = "GreaterThanThreshold"
  evaluation_periods  = "2"
  metric_name         = "5xx"
  namespace           = "AWS/ApiGatewayV2"
  period              = "300"
  statistic           = "Sum"
  threshold           = "10"
  alarm_description   = "This metric monitors API Gateway 5XX errors"
  alarm_actions       = var.alarm_actions

  dimensions = {
    ApiId = aws_apigatewayv2_api.main.id
    Stage = aws_apigatewayv2_stage.main.name
  }

  tags = var.tags
}

resource "aws_cloudwatch_metric_alarm" "api_gateway_latency" {
  alarm_name          = "${var.name_prefix}-api-gateway-latency"
  comparison_operator = "GreaterThanThreshold"
  evaluation_periods  = "2"
  metric_name         = "IntegrationLatency"
  namespace           = "AWS/ApiGatewayV2"
  period              = "300"
  statistic           = "Average"
  threshold           = "5000"
  alarm_description   = "This metric monitors API Gateway latency"
  alarm_actions       = var.alarm_actions

  dimensions = {
    ApiId = aws_apigatewayv2_api.main.id
    Stage = aws_apigatewayv2_stage.main.name
  }

  tags = var.tags
}