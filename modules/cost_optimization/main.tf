terraform {
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
    random = {
      source  = "hashicorp/random"
      version = "~> 3.1"
    }
  }
}

# Get current AWS account ID and region
data "aws_caller_identity" "current" {}
data "aws_region" "current" {}

# Cost Budget with alerts - FIXED SYNTAX
resource "aws_budgets_budget" "monthly_cost" {
  name         = "${var.name_prefix}-monthly-budget"
  budget_type  = "COST"
  limit_amount = var.monthly_budget_limit
  limit_unit   = "USD"
  time_unit    = "MONTHLY"
  
  # Budget period
  time_period_start = formatdate("YYYY-MM-01_00:00", timestamp())
  
  # FIXED: Proper cost_filter syntax
  cost_filter {
    name   = "TagKey"
    values = ["Project"]
  }

  cost_filter {
    name   = "Tag"
    values = ["Project$${var.project_name}"]
  }

  # Budget notifications
  notification {
    comparison_operator        = "GREATER_THAN"
    threshold                 = 80
    threshold_type            = "PERCENTAGE"
    notification_type          = "ACTUAL"
    subscriber_email_addresses = var.budget_alert_emails
  }

  notification {
    comparison_operator        = "GREATER_THAN"
    threshold                 = 90
    threshold_type            = "PERCENTAGE"
    notification_type          = "FORECASTED"
    subscriber_email_addresses = var.budget_alert_emails
  }

  notification {
    comparison_operator        = "GREATER_THAN"
    threshold                 = 100
    threshold_type            = "PERCENTAGE"
    notification_type          = "ACTUAL"
    subscriber_email_addresses = var.critical_alert_emails
  }

  tags = var.tags
}

# Service-specific budgets - FIXED SYNTAX
resource "aws_budgets_budget" "compute_budget" {
  name         = "${var.name_prefix}-compute-budget"
  budget_type  = "COST"
  limit_amount = var.compute_budget_limit
  limit_unit   = "USD"
  time_unit    = "MONTHLY"
  
  time_period_start = formatdate("YYYY-MM-01_00:00", timestamp())
  
  # FIXED: Multiple cost_filter blocks with proper syntax
  cost_filter {
    name   = "Service"
    values = ["Amazon Elastic Compute Cloud - Compute", "Amazon EC2 Container Service"]
  }

  cost_filter {
    name   = "Tag"
    values = ["Project$${var.project_name}"]
  }

  notification {
    comparison_operator        = "GREATER_THAN"
    threshold                 = 85
    threshold_type            = "PERCENTAGE"
    notification_type          = "ACTUAL"
    subscriber_email_addresses = var.budget_alert_emails
  }

  tags = var.tags
}

resource "aws_budgets_budget" "database_budget" {
  name         = "${var.name_prefix}-database-budget"
  budget_type  = "COST"
  limit_amount = var.database_budget_limit
  limit_unit   = "USD"
  time_unit    = "MONTHLY"
  
  time_period_start = formatdate("YYYY-MM-01_00:00", timestamp())
  
  # FIXED: Proper cost_filter syntax
  cost_filter {
    name   = "Service"
    values = ["Amazon Relational Database Service", "Amazon ElastiCache"]
  }

  cost_filter {
    name   = "Tag"
    values = ["Project$${var.project_name}"]
  }

  notification {
    comparison_operator        = "GREATER_THAN"
    threshold                 = 85
    threshold_type            = "PERCENTAGE"
    notification_type          = "ACTUAL"
    subscriber_email_addresses = var.budget_alert_emails
  }

  tags = var.tags
}

# Cost Anomaly Detection - FIXED SYNTAX
resource "aws_ce_anomaly_detector" "cost_anomaly" {
  name         = "${var.name_prefix}-cost-anomaly-detector"
  monitor_type = "DIMENSIONAL"

  # FIXED: Correct specification format
  specification = jsonencode({
    "Dimension" = {
      "Key"          = "SERVICE"
      "Values"       = ["EC2-Instance"]
      "MatchOptions" = ["EQUALS"]
    }
  })

  tags = var.tags
}

resource "aws_ce_anomaly_subscription" "cost_anomaly_alerts" {
  name      = "${var.name_prefix}-cost-anomaly-alerts"
  frequency = "DAILY"
  
  monitor_arn_list = [
    aws_ce_anomaly_detector.cost_anomaly.arn
  ]
  
  subscriber {
    type    = "EMAIL"
    address = var.cost_anomaly_email
  }

  threshold_expression {
    and {
      dimension {
        key           = "ANOMALY_TOTAL_IMPACT_ABSOLUTE"
        values        = ["100"]
        match_options = ["GREATER_THAN_OR_EQUAL"]
      }
    }
  }

  tags = var.tags
}

# CloudWatch dashboards for cost monitoring
resource "aws_cloudwatch_dashboard" "cost_monitoring" {
  dashboard_name = "${var.name_prefix}-cost-monitoring"

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
            ["AWS/Billing", "EstimatedCharges", "Currency", "USD"],
            ["AWS/EC2", "RunningInstances"],
            ["AWS/RDS", "DatabaseConnections"],
            ["AWS/ElastiCache", "NetworkBytesIn"]
          ]
          period = 86400
          stat   = "Average"
          region = "us-east-1"
          title  = "Daily Cost and Usage Metrics"
        }
      },
      {
        type   = "text"
        x      = 12
        y      = 0
        width  = 12
        height = 6

        properties = {
          markdown = "## Cost Optimization Recommendations\n\n**Current Month Budget**: $${var.monthly_budget_limit}\n\n**Key Metrics to Watch**:\n- ECS Task Count\n- RDS Connection Pool Usage\n- ElastiCache Memory Utilization\n- S3 Storage Classes\n\n**Optimization Actions**:\n1. Enable Spot Instances for dev/test\n2. Schedule non-prod environments\n3. Optimize S3 storage classes\n4. Right-size ECS tasks"
        }
      }
    ]
  })
}

# Cost optimization Lambda function
resource "aws_lambda_function" "cost_optimizer" {
  filename         = data.archive_file.cost_optimizer.output_path
  function_name    = "${var.name_prefix}-cost-optimizer"
  role            = aws_iam_role.cost_optimizer.arn
  handler         = "cost_optimizer.handler"
  source_code_hash = data.archive_file.cost_optimizer.output_base64sha256
  runtime         = "python3.11"
  timeout         = 300

  environment {
    variables = {
      PROJECT_NAME          = var.project_name
      ENVIRONMENT          = var.environment
      SLACK_WEBHOOK_URL    = var.slack_webhook_url
      SNS_TOPIC_ARN        = aws_sns_topic.cost_alerts.arn
    }
  }

  tags = var.tags
}

# Schedule cost optimization checks
resource "aws_cloudwatch_event_rule" "cost_optimization_schedule" {
  name                = "${var.name_prefix}-cost-optimization"
  description         = "Trigger cost optimization analysis"
  schedule_expression = "cron(0 6 * * ? *)" # Daily at 6 AM UTC

  tags = var.tags
}

resource "aws_cloudwatch_event_target" "cost_optimizer_target" {
  rule      = aws_cloudwatch_event_rule.cost_optimization_schedule.name
  target_id = "CostOptimizerTarget"
  arn       = aws_lambda_function.cost_optimizer.arn
}

resource "aws_lambda_permission" "allow_cost_optimizer_eventbridge" {
  statement_id  = "AllowExecutionFromEventBridge"
  action        = "lambda:InvokeFunction"
  function_name = aws_lambda_function.cost_optimizer.function_name
  principal     = "events.amazonaws.com"
  source_arn    = aws_cloudwatch_event_rule.cost_optimization_schedule.arn
}

# SNS topic for cost alerts
resource "aws_sns_topic" "cost_alerts" {
  name = "${var.name_prefix}-cost-alerts"
  tags = var.tags
}

resource "aws_sns_topic_subscription" "cost_alert_emails" {
  count     = length(var.cost_alert_emails)
  topic_arn = aws_sns_topic.cost_alerts.arn
  protocol  = "email"
  endpoint  = var.cost_alert_emails[count.index]
}

# IAM role for cost optimizer Lambda
resource "aws_iam_role" "cost_optimizer" {
  name = "${var.name_prefix}-cost-optimizer-role"

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

resource "aws_iam_role_policy" "cost_optimizer" {
  name = "${var.name_prefix}-cost-optimizer-policy"
  role = aws_iam_role.cost_optimizer.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Action = [
          "ce:GetCostAndUsage",
          "ce:GetUsageReport",
          "ce:GetReservationCoverage",
          "ce:GetReservationPurchaseRecommendation",
          "ce:GetReservationUtilization",
          "ce:GetRightsizingRecommendation",
          "pricing:GetProducts",
          "pricing:GetAttributeValues"
        ]
        Resource = "*"
      },
      {
        Effect = "Allow"
        Action = [
          "ec2:DescribeInstances",
          "ec2:DescribeReservedInstances",
          "ecs:DescribeClusters",
          "ecs:DescribeServices",
          "ecs:DescribeTasks",
          "rds:DescribeDBInstances",
          "rds:DescribeReservedDBInstances",
          "elasticache:DescribeCacheClusters",
          "elasticache:DescribeReservedCacheNodes"
        ]
        Resource = "*"
      },
      {
        Effect = "Allow"
        Action = [
          "sns:Publish"
        ]
        Resource = aws_sns_topic.cost_alerts.arn
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

# Reserved Instance recommendations
resource "aws_cloudwatch_metric_alarm" "high_monthly_cost" {
  alarm_name          = "${var.name_prefix}-high-monthly-cost"
  comparison_operator = "GreaterThanThreshold"
  evaluation_periods  = "1"
  metric_name         = "EstimatedCharges"
  namespace           = "AWS/Billing"
  period              = "86400"
  statistic           = "Maximum"
  threshold           = var.monthly_budget_limit * 0.9
  alarm_description   = "Monthly costs approaching budget limit"
  alarm_actions       = [aws_sns_topic.cost_alerts.arn]

  dimensions = {
    Currency = "USD"
  }

  tags = var.tags
}

# Savings Plans recommendations (placeholder for future implementation)
resource "aws_cloudwatch_log_group" "cost_optimization" {
  name              = "/aws/lambda/${aws_lambda_function.cost_optimizer.function_name}"
  retention_in_days = 14

  tags = var.tags
}

# Package the cost optimizer Lambda function
data "archive_file" "cost_optimizer" {
  type        = "zip"
  output_path = "/tmp/cost_optimizer.zip"
  source {
    content = templatefile("${path.module}/lambda/cost_optimizer.py", {
      project_name = var.project_name
    })
    filename = "cost_optimizer.py"
  }
}

# Auto Scaling for cost optimization - ONLY if autoscaling_group_name is provided
resource "aws_autoscaling_schedule" "scale_down_non_prod" {
  count                  = var.environment != "production" && var.autoscaling_group_name != "" ? 1 : 0
  scheduled_action_name  = "${var.name_prefix}-scale-down-evening"
  min_size              = 0
  max_size              = 1
  desired_capacity      = 0
  recurrence            = "0 20 * * *" # Scale down at 8 PM UTC
  autoscaling_group_name = var.autoscaling_group_name
}

resource "aws_autoscaling_schedule" "scale_up_non_prod" {
  count                  = var.environment != "production" && var.autoscaling_group_name != "" ? 1 : 0
  scheduled_action_name  = "${var.name_prefix}-scale-up-morning"
  min_size              = 1
  max_size              = 10
  desired_capacity      = 2
  recurrence            = "0 8 * * *" # Scale up at 8 AM UTC
  autoscaling_group_name = var.autoscaling_group_name
}