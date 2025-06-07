resource "aws_cloudwatch_log_group" "ecs" {
  name              = "/ecs/${var.name_prefix}"
  retention_in_days = var.log_retention_days

  tags = merge(var.tags, {
    Name = "${var.name_prefix}-ecs-logs"
  })
}

resource "aws_cloudwatch_metric_alarm" "high_cpu" {
  alarm_name          = "${var.name_prefix}-high-cpu"
  comparison_operator = "GreaterThanThreshold"
  evaluation_periods  = "2"
  metric_name         = "CPUUtilization"
  namespace           = "AWS/ECS"
  period              = "300"
  statistic           = "Average"
  threshold           = "80"
  alarm_description   = "This metric monitors ecs cpu utilization"
  treat_missing_data  = "notBreaching"

  dimensions = {
    ServiceName = "${var.name_prefix}-api"
    ClusterName = var.cluster_name
  }

  tags = merge(var.tags, {
    Name = "${var.name_prefix}-high-cpu-alarm"
  })
}

resource "aws_cloudwatch_metric_alarm" "high_memory" {
  alarm_name          = "${var.name_prefix}-high-memory"
  comparison_operator = "GreaterThanThreshold"
  evaluation_periods  = "2"
  metric_name         = "MemoryUtilization"
  namespace           = "AWS/ECS"
  period              = "300"
  statistic           = "Average"
  threshold           = "85"
  alarm_description   = "This metric monitors ecs memory utilization"
  treat_missing_data  = "notBreaching"

  dimensions = {
    ServiceName = "${var.name_prefix}-api"
    ClusterName = var.cluster_name
  }

  tags = merge(var.tags, {
    Name = "${var.name_prefix}-high-memory-alarm"
  })
}

# Custom metrics dashboard (optional)
resource "aws_cloudwatch_dashboard" "main" {
  count          = var.enable_custom_metrics ? 1 : 0
  dashboard_name = "${var.name_prefix}-dashboard"

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
            ["AWS/ECS", "CPUUtilization", "ServiceName", "${var.name_prefix}-api", "ClusterName", var.cluster_name],
            [".", "MemoryUtilization", ".", ".", ".", "."]
          ]
          period = 300
          stat   = "Average"
          region = var.aws_region
          title  = "ECS Service Metrics"
        }
      }
    ]
  })
}