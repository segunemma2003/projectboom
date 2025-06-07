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

# NEW - Missing outputs that your main.tf is referencing
output "alb_full_name" {
  description = "Full name of the Application Load Balancer"
  value       = aws_lb.main.arn_suffix
}

output "https_listener_arn" {
  description = "HTTPS listener ARN"
  value       = aws_lb_listener.https.arn
}