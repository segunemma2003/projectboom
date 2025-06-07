resource "aws_cloudwatch_log_group" "ecs" {
  name              = "/ecs/${var.name_prefix}"
  retention_in_days = 7

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

  dimensions = {
    ServiceName = "${var.name_prefix}-api"
    ClusterName = var.cluster_name
  }

  tags = merge(var.tags, {
    Name = "${var.name_prefix}-high-memory-alarm"
  })
}