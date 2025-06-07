output "zone_id" {
  description = "Route 53 hosted zone ID"
  value       = aws_route53_zone.main.zone_id
}

output "zone_arn" {
  description = "Route 53 hosted zone ARN"
  value       = aws_route53_zone.main.arn
}

output "name_servers" {
  description = "Route 53 name servers"
  value       = aws_route53_zone.main.name_servers
}

output "primary_health_check_id" {
  description = "Primary health check ID"
  value       = var.enable_health_checks ? aws_route53_health_check.primary[0].id : null
}

output "secondary_health_check_id" {
  description = "Secondary health check ID"
  value       = var.enable_health_checks && var.secondary_endpoint != "" ? aws_route53_health_check.secondary[0].id : null
}