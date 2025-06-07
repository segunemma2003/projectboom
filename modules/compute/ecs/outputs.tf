output "cluster_id" {
  description = "ECS cluster ID"
  value       = aws_ecs_cluster.main.id
}

output "cluster_name" {
  description = "ECS cluster name"
  value       = aws_ecs_cluster.main.name
}

output "service_names" {
  description = "ECS service names"
  value       = { for k, v in aws_ecs_service.app : k => v.name }
}

output "task_definition_arns" {
  description = "ECS task definition ARNs"
  value       = { for k, v in aws_ecs_task_definition.app : k => v.arn }
}