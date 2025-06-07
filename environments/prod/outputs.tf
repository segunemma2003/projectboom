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
  value       = module.redis.main_cluster_configuration_endpoint
  sensitive   = true
}

output "load_balancer_dns" {
  description = "Load balancer DNS name"
  value       = module.load_balancer.dns_name
}

output "cloudfront_domain" {
  description = "CloudFront domain name"
  value       = module.cloudfront.domain_name
}

output "ecs_cluster_name" {
  description = "ECS cluster name"
  value       = module.ecs.cluster_name
}

# Additional outputs for production monitoring
output "api_gateway_endpoint" {
  description = "API Gateway endpoint URL"
  value       = try(module.api_gateway.api_gateway_endpoint, "")
}

output "livekit_alb_dns" {
  description = "LiveKit ALB DNS name"
  value       = try(module.livekit.alb_dns_name, "")
}

output "monitoring_dashboard_url" {
  description = "CloudWatch dashboard URL"
  value       = "https://${var.aws_region}.console.aws.amazon.com/cloudwatch/home?region=${var.aws_region}#dashboards:"
}

output "database_proxy_endpoint" {
  description = "RDS Proxy endpoint"
  value       = module.database.proxy_endpoint
  sensitive   = true
}