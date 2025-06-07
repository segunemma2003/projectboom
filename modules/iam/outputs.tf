output "ecs_execution_role_arn" {
  description = "ECS execution role ARN"
  value       = aws_iam_role.ecs_execution.arn
}

output "ecs_task_role_arn" {
  description = "ECS task role ARN"
  value       = aws_iam_role.ecs_task.arn
}

output "rds_monitoring_role_arn" {
  description = "RDS monitoring role ARN"
  value       = aws_iam_role.rds_monitoring.arn
}
