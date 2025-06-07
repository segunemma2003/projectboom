output "main_cluster_configuration_endpoint" {
  description = "Configuration endpoint for main Redis cluster"
  value       = aws_elasticache_replication_group.main.configuration_endpoint_address
}

output "main_cluster_id" {
  description = "Main Redis cluster ID"
  value       = aws_elasticache_replication_group.main.replication_group_id
}

output "sessions_cluster_configuration_endpoint" {
  description = "Configuration endpoint for sessions Redis cluster"
  value       = aws_elasticache_replication_group.sessions.configuration_endpoint_address
}

output "sessions_cluster_id" {
  description = "Sessions Redis cluster ID"
  value       = aws_elasticache_replication_group.sessions.replication_group_id
}

output "realtime_cluster_configuration_endpoint" {
  description = "Configuration endpoint for real-time Redis cluster"
  value       = aws_elasticache_replication_group.realtime.configuration_endpoint_address
}

output "realtime_cluster_id" {
  description = "Real-time Redis cluster ID"
  value       = aws_elasticache_replication_group.realtime.replication_group_id
}

output "auth_token_secret_arn" {
  description = "ARN of the Redis auth token secret"
  value       = var.auth_token_enabled ? aws_secretsmanager_secret.redis_auth_token[0].arn : null
}

output "primary_endpoints" {
  description = "Primary endpoints for all Redis clusters"
  value = {
    main     = aws_elasticache_replication_group.main.configuration_endpoint_address
    sessions = aws_elasticache_replication_group.sessions.configuration_endpoint_address
    realtime = aws_elasticache_replication_group.realtime.configuration_endpoint_address
  }
}

output "subnet_group_name" {
  description = "ElastiCache subnet group name"
  value       = aws_elasticache_subnet_group.main.name
}