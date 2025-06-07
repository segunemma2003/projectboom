output "alb_dns_name" {
  description = "LiveKit ALB DNS name"
  value       = aws_lb.livekit.dns_name
}

output "alb_zone_id" {
  description = "LiveKit ALB zone ID"
  value       = aws_lb.livekit.zone_id
}

output "nlb_dns_name" {
  description = "LiveKit NLB DNS name"
  value       = aws_lb.livekit_turn.dns_name
}

output "nlb_zone_id" {
  description = "LiveKit NLB zone ID"
  value       = aws_lb.livekit_turn.zone_id
}

output "service_name" {
  description = "LiveKit ECS service name"
  value       = aws_ecs_service.livekit.name
}

output "service_arn" {
  description = "LiveKit ECS service ARN"
  value       = aws_ecs_service.livekit.id
}

output "api_key_secret_arn" {
  description = "LiveKit API credentials secret ARN"
  value       = aws_secretsmanager_secret.livekit_credentials.arn
}

output "security_group_id" {
  description = "LiveKit ECS security group ID"
  value       = aws_security_group.livekit_ecs.id
}

output "log_group_name" {
  description = "LiveKit CloudWatch log group name"
  value       = aws_cloudwatch_log_group.livekit.name
}