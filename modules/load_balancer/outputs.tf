output "dns_name" {
  description = "Load balancer DNS name"
  value       = aws_lb.main.dns_name
}

output "zone_id" {
  description = "Load balancer zone ID"
  value       = aws_lb.main.zone_id
}

output "api_target_group_arn" {
  description = "API target group ARN"
  value       = aws_lb_target_group.api.arn
}

output "websocket_target_group_arn" {
  description = "WebSocket target group ARN"
  value       = aws_lb_target_group.websocket.arn
}