resource "aws_elasticache_subnet_group" "main" {
  name       = "${var.name_prefix}-redis-cluster-subnet-group"
  subnet_ids = var.subnet_ids

  tags = merge(var.tags, {
    Name = "${var.name_prefix}-redis-cluster-subnet-group"
  })
}

# Parameter group for Redis cluster
resource "aws_elasticache_parameter_group" "main" {
  family = "redis7.x"
  name   = "${var.name_prefix}-redis-cluster-params"

  parameter {
    name  = "cluster-enabled"
    value = "yes"
  }

  parameter {
    name  = "maxmemory-policy"
    value = "allkeys-lru"
  }

  parameter {
    name  = "timeout"
    value = "300"
  }

  parameter {
    name  = "tcp-keepalive"
    value = "300"
  }

  tags = var.tags
}

# Main Redis Cluster for application data
resource "aws_elasticache_replication_group" "main" {
  replication_group_id         = "${var.name_prefix}-redis-cluster"
  description                  = "Redis cluster for ${var.name_prefix}"

  # Cluster configuration
  node_type                    = var.node_type
  port                         = 6379
  parameter_group_name         = aws_elasticache_parameter_group.main.name

  # Cluster mode configuration
  num_cache_clusters           = null
  num_node_groups             = var.num_node_groups
  replicas_per_node_group     = var.replicas_per_node_group

  # Network configuration
  subnet_group_name           = aws_elasticache_subnet_group.main.name
  security_group_ids          = var.security_group_ids

  # High availability
  automatic_failover_enabled   = true
  multi_az_enabled            = true

  # Security
  at_rest_encryption_enabled   = true
  transit_encryption_enabled   = true
  auth_token                  = var.auth_token_enabled ? random_password.auth_token[0].result : null

  # Maintenance
  maintenance_window          = "sun:03:00-sun:04:00"
  snapshot_retention_limit    = var.snapshot_retention_limit
  snapshot_window            = "02:00-03:00"

  # Notifications
  notification_topic_arn      = var.notification_topic_arn

  # Logging
  log_delivery_configuration {
    destination      = aws_cloudwatch_log_group.redis_slow.name
    destination_type = "cloudwatch-logs"
    log_format      = "text"
    log_type        = "slow-log"
  }

  tags = merge(var.tags, {
    Name = "${var.name_prefix}-redis-cluster"
    Type = "Primary"
  })

  depends_on = [aws_cloudwatch_log_group.redis_slow]
}

# Separate Redis cluster for sessions (single-node groups for session affinity)
resource "aws_elasticache_replication_group" "sessions" {
  replication_group_id         = "${var.name_prefix}-redis-sessions"
  description                  = "Redis cluster for user sessions"

  # Configuration
  node_type                    = var.session_node_type
  port                         = 6379
  parameter_group_name         = "default.redis7.cluster.on"

  # Single node groups for session stickiness
  num_node_groups             = var.session_num_node_groups
  replicas_per_node_group     = 1

  # Network configuration
  subnet_group_name           = aws_elasticache_subnet_group.main.name
  security_group_ids          = var.security_group_ids

  # High availability
  automatic_failover_enabled   = true
  multi_az_enabled            = true

  # Security
  at_rest_encryption_enabled   = true
  transit_encryption_enabled   = true
  auth_token                  = var.auth_token_enabled ? random_password.auth_token[0].result : null

  # Maintenance
  maintenance_window          = "sun:04:00-sun:05:00"
  snapshot_retention_limit    = 3
  snapshot_window            = "01:00-02:00"

  tags = merge(var.tags, {
    Name = "${var.name_prefix}-redis-sessions"
    Type = "Sessions"
  })
}

# Redis cluster for real-time features (chat, notifications)
resource "aws_elasticache_replication_group" "realtime" {
  replication_group_id         = "${var.name_prefix}-redis-realtime"
  description                  = "Redis cluster for real-time features"

  # Configuration optimized for pub/sub
  node_type                    = var.realtime_node_type
  port                         = 6379
  parameter_group_name         = aws_elasticache_parameter_group.realtime.name

  # Configuration for pub/sub workloads
  num_node_groups             = var.realtime_num_node_groups
  replicas_per_node_group     = 2

  # Network configuration
  subnet_group_name           = aws_elasticache_subnet_group.main.name
  security_group_ids          = var.security_group_ids

  # High availability
  automatic_failover_enabled   = true
  multi_az_enabled            = true

  # Security
  at_rest_encryption_enabled   = true
  transit_encryption_enabled   = true
  auth_token                  = var.auth_token_enabled ? random_password.auth_token[0].result : null

  # Maintenance
  maintenance_window          = "sun:05:00-sun:06:00"
  snapshot_retention_limit    = 1

  tags = merge(var.tags, {
    Name = "${var.name_prefix}-redis-realtime"
    Type = "Realtime"
  })
}

# Parameter group for real-time Redis cluster
resource "aws_elasticache_parameter_group" "realtime" {
  family = "redis7.x"
  name   = "${var.name_prefix}-redis-realtime-params"

  parameter {
    name  = "cluster-enabled"
    value = "yes"
  }

  parameter {
    name  = "maxmemory-policy"
    value = "noeviction"
  }

  parameter {
    name  = "notify-keyspace-events"
    value = "Ex"
  }

  parameter {
    name  = "timeout"
    value = "0"
  }

  tags = var.tags
}

# Auth token for Redis clusters
resource "random_password" "auth_token" {
  count   = var.auth_token_enabled ? 1 : 0
  length  = 32
  special = false
}

resource "aws_secretsmanager_secret" "redis_auth_token" {
  count                   = var.auth_token_enabled ? 1 : 0
  name                    = "${var.name_prefix}/redis/auth-token"
  recovery_window_in_days = 7
  tags                    = var.tags
}

resource "aws_secretsmanager_secret_version" "redis_auth_token" {
  count     = var.auth_token_enabled ? 1 : 0
  secret_id = aws_secretsmanager_secret.redis_auth_token[0].id
  secret_string = jsonencode({
    auth_token = random_password.auth_token[0].result
  })
}

# CloudWatch Log Groups
resource "aws_cloudwatch_log_group" "redis_slow" {
  name              = "/aws/elasticache/${var.name_prefix}/redis-slow-log"
  retention_in_days = var.log_retention_days

  tags = merge(var.tags, {
    Name = "${var.name_prefix}-redis-slow-logs"
  })
}

# CloudWatch Alarms
resource "aws_cloudwatch_metric_alarm" "high_cpu" {
  alarm_name          = "${var.name_prefix}-redis-high-cpu"
  comparison_operator = "GreaterThanThreshold"
  evaluation_periods  = "2"
  metric_name         = "CPUUtilization"
  namespace           = "AWS/ElastiCache"
  period              = "300"
  statistic           = "Average"
  threshold           = "80"
  alarm_description   = "This metric monitors Redis CPU utilization"
  alarm_actions       = var.alarm_actions

  dimensions = {
    CacheClusterId = aws_elasticache_replication_group.main.id
  }

  tags = var.tags
}

resource "aws_cloudwatch_metric_alarm" "high_memory" {
  alarm_name          = "${var.name_prefix}-redis-high-memory"
  comparison_operator = "GreaterThanThreshold"
  evaluation_periods  = "2"
  metric_name         = "DatabaseMemoryUsagePercentage"
  namespace           = "AWS/ElastiCache"
  period              = "300"
  statistic           = "Average"
  threshold           = "85"
  alarm_description   = "This metric monitors Redis memory utilization"
  alarm_actions       = var.alarm_actions

  dimensions = {
    CacheClusterId = aws_elasticache_replication_group.main.id
  }

  tags = var.tags
}