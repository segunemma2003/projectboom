# Budget Outputs
output "monthly_budget_name" {
  description = "Name of the monthly cost budget"
  value       = aws_budgets_budget.monthly_cost.name
}

output "monthly_budget_arn" {
  description = "ARN of the monthly cost budget"
  value       = aws_budgets_budget.monthly_cost.budget_name
}

output "monthly_budget_limit" {
  description = "Monthly budget limit amount in USD"
  value       = aws_budgets_budget.monthly_cost.limit_amount
}

output "compute_budget_name" {
  description = "Name of the compute service budget"
  value       = aws_budgets_budget.compute_budget.name
}

output "compute_budget_arn" {
  description = "ARN of the compute service budget"
  value       = aws_budgets_budget.compute_budget.budget_name
}

output "compute_budget_limit" {
  description = "Compute budget limit amount in USD"
  value       = aws_budgets_budget.compute_budget.limit_amount
}

output "database_budget_name" {
  description = "Name of the database service budget"
  value       = aws_budgets_budget.database_budget.name
}

output "database_budget_arn" {
  description = "ARN of the database service budget"
  value       = aws_budgets_budget.database_budget.budget_name
}

output "database_budget_limit" {
  description = "Database budget limit amount in USD"
  value       = aws_budgets_budget.database_budget.limit_amount
}

output "all_budgets" {
  description = "Summary of all created budgets"
  value = {
    monthly = {
      name  = aws_budgets_budget.monthly_cost.name
      limit = aws_budgets_budget.monthly_cost.limit_amount
      unit  = aws_budgets_budget.monthly_cost.limit_unit
    }
    compute = {
      name  = aws_budgets_budget.compute_budget.name
      limit = aws_budgets_budget.compute_budget.limit_amount
      unit  = aws_budgets_budget.compute_budget.limit_unit
    }
    database = {
      name  = aws_budgets_budget.database_budget.name
      limit = aws_budgets_budget.database_budget.limit_amount
      unit  = aws_budgets_budget.database_budget.limit_unit
    }
  }
}

# Cost Anomaly Detection Outputs
output "cost_anomaly_detector_arn" {
  description = "ARN of the cost anomaly detector"
  value       = aws_ce_anomaly_detector.cost_anomaly.arn
}

output "cost_anomaly_detector_name" {
  description = "Name of the cost anomaly detector"
  value       = aws_ce_anomaly_detector.cost_anomaly.name
}

output "cost_anomaly_subscription_arn" {
  description = "ARN of the cost anomaly subscription"
  value       = aws_ce_anomaly_subscription.cost_anomaly_alerts.arn
}

output "cost_anomaly_subscription_name" {
  description = "Name of the cost anomaly subscription"
  value       = aws_ce_anomaly_subscription.cost_anomaly_alerts.name
}

# CloudWatch Dashboard Outputs
output "cost_monitoring_dashboard_name" {
  description = "Name of the cost monitoring CloudWatch dashboard"
  value       = aws_cloudwatch_dashboard.cost_monitoring.dashboard_name
}

output "cost_monitoring_dashboard_url" {
  description = "URL to access the cost monitoring dashboard"
  value       = "https://${data.aws_region.current.name}.console.aws.amazon.com/cloudwatch/home?region=${data.aws_region.current.name}#dashboards:name=${aws_cloudwatch_dashboard.cost_monitoring.dashboard_name}"
}

# Lambda Function Outputs
output "cost_optimizer_function_name" {
  description = "Name of the cost optimizer Lambda function"
  value       = aws_lambda_function.cost_optimizer.function_name
}

output "cost_optimizer_function_arn" {
  description = "ARN of the cost optimizer Lambda function"
  value       = aws_lambda_function.cost_optimizer.arn
}

output "cost_optimizer_invoke_arn" {
  description = "Invoke ARN of the cost optimizer Lambda function"
  value       = aws_lambda_function.cost_optimizer.invoke_arn
}

output "cost_optimizer_role_arn" {
  description = "ARN of the cost optimizer Lambda IAM role"
  value       = aws_iam_role.cost_optimizer.arn
}

output "cost_optimizer_role_name" {
  description = "Name of the cost optimizer Lambda IAM role"
  value       = aws_iam_role.cost_optimizer.name
}

# EventBridge Outputs
output "cost_optimization_schedule_rule_name" {
  description = "Name of the cost optimization schedule EventBridge rule"
  value       = aws_cloudwatch_event_rule.cost_optimization_schedule.name
}

output "cost_optimization_schedule_rule_arn" {
  description = "ARN of the cost optimization schedule EventBridge rule"
  value       = aws_cloudwatch_event_rule.cost_optimization_schedule.arn
}

output "cost_optimization_schedule" {
  description = "Schedule expression for cost optimization checks"
  value       = aws_cloudwatch_event_rule.cost_optimization_schedule.schedule_expression
}

# SNS Topic Outputs
output "cost_alerts_topic_arn" {
  description = "ARN of the cost alerts SNS topic"
  value       = aws_sns_topic.cost_alerts.arn
}

output "cost_alerts_topic_name" {
  description = "Name of the cost alerts SNS topic"
  value       = aws_sns_topic.cost_alerts.name
}

output "cost_alert_subscriptions" {
  description = "List of cost alert email subscription ARNs"
  value       = [for sub in aws_sns_topic_subscription.cost_alert_emails : sub.arn]
}

output "cost_alert_subscriber_count" {
  description = "Number of email subscribers for cost alerts"
  value       = length(aws_sns_topic_subscription.cost_alert_emails)
}

# CloudWatch Alarms Outputs
output "high_monthly_cost_alarm_name" {
  description = "Name of the high monthly cost CloudWatch alarm"
  value       = aws_cloudwatch_metric_alarm.high_monthly_cost.alarm_name
}

output "high_monthly_cost_alarm_arn" {
  description = "ARN of the high monthly cost CloudWatch alarm"
  value       = aws_cloudwatch_metric_alarm.high_monthly_cost.arn
}

output "high_monthly_cost_threshold" {
  description = "Threshold value for the high monthly cost alarm"
  value       = aws_cloudwatch_metric_alarm.high_monthly_cost.threshold
}

# CloudWatch Log Group Outputs
output "cost_optimization_log_group_name" {
  description = "Name of the cost optimization CloudWatch log group"
  value       = aws_cloudwatch_log_group.cost_optimization.name
}

output "cost_optimization_log_group_arn" {
  description = "ARN of the cost optimization CloudWatch log group"
  value       = aws_cloudwatch_log_group.cost_optimization.arn
}

# Auto Scaling Outputs (conditional)
output "scale_down_schedule_name" {
  description = "Name of the scale down schedule (if created)"
  value       = var.environment != "production" && var.autoscaling_group_name != "" ? aws_autoscaling_schedule.scale_down_non_prod[0].scheduled_action_name : null
}

output "scale_up_schedule_name" {
  description = "Name of the scale up schedule (if created)"
  value       = var.environment != "production" && var.autoscaling_group_name != "" ? aws_autoscaling_schedule.scale_up_non_prod[0].scheduled_action_name : null
}

output "auto_scaling_schedules" {
  description = "Auto scaling schedule configuration (if created)"
  value = var.environment != "production" && var.autoscaling_group_name != "" ? {
    scale_down = {
      name             = aws_autoscaling_schedule.scale_down_non_prod[0].scheduled_action_name
      recurrence       = aws_autoscaling_schedule.scale_down_non_prod[0].recurrence
      desired_capacity = aws_autoscaling_schedule.scale_down_non_prod[0].desired_capacity
    }
    scale_up = {
      name             = aws_autoscaling_schedule.scale_up_non_prod[0].scheduled_action_name
      recurrence       = aws_autoscaling_schedule.scale_up_non_prod[0].recurrence
      desired_capacity = aws_autoscaling_schedule.scale_up_non_prod[0].desired_capacity
    }
  } : null
}

# Cost Management Configuration Summary
output "cost_management_configuration" {
  description = "Summary of cost management configuration"
  value = {
    budgets = {
      monthly_limit  = aws_budgets_budget.monthly_cost.limit_amount
      compute_limit  = aws_budgets_budget.compute_budget.limit_amount
      database_limit = aws_budgets_budget.database_budget.limit_amount
      currency       = aws_budgets_budget.monthly_cost.limit_unit
    }
    monitoring = {
      dashboard_name   = aws_cloudwatch_dashboard.cost_monitoring.dashboard_name
      anomaly_detector = aws_ce_anomaly_detector.cost_anomaly.name
      lambda_function  = aws_lambda_function.cost_optimizer.function_name
      schedule         = aws_cloudwatch_event_rule.cost_optimization_schedule.schedule_expression
    }
    alerts = {
      sns_topic         = aws_sns_topic.cost_alerts.name
      email_subscribers = length(aws_sns_topic_subscription.cost_alert_emails)
      alarm_threshold   = aws_cloudwatch_metric_alarm.high_monthly_cost.threshold
    }
    automation = {
      cost_optimizer_enabled = true
      auto_scaling_enabled   = var.environment != "production" && var.autoscaling_group_name != ""
      environment            = var.environment
    }
  }
}

# Notification Configuration
output "notification_configuration" {
  description = "Cost management notification configuration"
  value = {
    budget_alerts = {
      threshold_80_percent  = true
      threshold_90_percent  = true
      threshold_100_percent = true
      alert_emails          = var.budget_alert_emails
      critical_emails       = var.critical_alert_emails
    }
    anomaly_detection = {
      enabled            = true
      frequency          = aws_ce_anomaly_subscription.cost_anomaly_alerts.frequency
      threshold_amount   = 100
      notification_email = var.cost_anomaly_email
    }
    cloudwatch_alarms = {
      high_cost_alarm = {
        name      = aws_cloudwatch_metric_alarm.high_monthly_cost.alarm_name
        threshold = aws_cloudwatch_metric_alarm.high_monthly_cost.threshold
        actions   = [aws_sns_topic.cost_alerts.arn]
      }
    }
  }
}

# Security and IAM Configuration
output "iam_configuration" {
  description = "IAM configuration for cost management"
  value = {
    cost_optimizer_role = {
      name = aws_iam_role.cost_optimizer.name
      arn  = aws_iam_role.cost_optimizer.arn
    }
    permissions = {
      cost_explorer_access   = true
      pricing_api_access     = true
      ec2_describe_access    = true
      ecs_describe_access    = true
      rds_describe_access    = true
      sns_publish_access     = true
      cloudwatch_logs_access = true
    }
  }
}

# Resource Identifiers for External Integration
output "resource_identifiers" {
  description = "Resource identifiers for external integration"
  value = {
    monthly_budget_name          = aws_budgets_budget.monthly_cost.name
    compute_budget_name          = aws_budgets_budget.compute_budget.name
    database_budget_name         = aws_budgets_budget.database_budget.name
    cost_anomaly_detector_name   = aws_ce_anomaly_detector.cost_anomaly.name
    cost_optimizer_function_name = aws_lambda_function.cost_optimizer.function_name
    cost_alerts_topic_name       = aws_sns_topic.cost_alerts.name
    dashboard_name               = aws_cloudwatch_dashboard.cost_monitoring.dashboard_name
    log_group_name               = aws_cloudwatch_log_group.cost_optimization.name
    alarm_name                   = aws_cloudwatch_metric_alarm.high_monthly_cost.alarm_name
    schedule_rule_name           = aws_cloudwatch_event_rule.cost_optimization_schedule.name
  }
}

# Cost Optimization Insights
output "cost_optimization_insights" {
  description = "Cost optimization configuration and recommendations"
  value = {
    current_configuration = {
      project_name        = var.project_name
      environment         = var.environment
      monthly_budget      = var.monthly_budget_limit
      auto_scaling_active = var.environment != "production" && var.autoscaling_group_name != ""
    }
    optimization_features = {
      scheduled_scaling      = var.environment != "production"
      cost_anomaly_detection = true
      automated_analysis     = true
      budget_alerts          = true
      dashboard_monitoring   = true
    }
    recommendations = {
      enable_reserved_instances = var.monthly_budget_limit > 500
      enable_savings_plans      = var.monthly_budget_limit > 1000
      review_frequency          = "daily"
      optimization_schedule     = "06:00 UTC daily"
    }
  }
}

# Monitoring URLs and Access
output "monitoring_access" {
  description = "URLs and access information for cost monitoring"
  value = {
    dashboard_url         = "https://${data.aws_region.current.name}.console.aws.amazon.com/cloudwatch/home?region=${data.aws_region.current.name}#dashboards:name=${aws_cloudwatch_dashboard.cost_monitoring.dashboard_name}"
    budgets_console_url   = "https://console.aws.amazon.com/billing/home#/budgets"
    cost_explorer_url     = "https://console.aws.amazon.com/cost-management/home#/cost-explorer"
    anomaly_detection_url = "https://console.aws.amazon.com/cost-management/home#/anomaly-detection"
    lambda_function_url   = "https://${data.aws_region.current.name}.console.aws.amazon.com/lambda/home?region=${data.aws_region.current.name}#/functions/${aws_lambda_function.cost_optimizer.function_name}"
  }
  sensitive = false
}