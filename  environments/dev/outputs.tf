output "vpc_id" {
  description = "VPC ID"
  value       = module.networking.vpc_id
}

output "database_endpoint" {
  description = "Database endpoint"
  value       = module.database.endpoint
  sensitive   = true
}

output "redis_endpoint" {
  description = "Redis endpoint"
  value       = module.redis.primary_endpoint
  sensitive   = true
}

output "load_balancer_dns" {
  description = "Load balancer DNS name"
  value       = module.load_balancer.dns_name
}

output "ecs_cluster_name" {
  description = "ECS cluster name"
  value       = module.ecs.cluster_name
}
  