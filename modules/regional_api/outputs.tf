output "api_gateway_id" {
  description = "Regional API Gateway ID"
  value       = aws_apigatewayv2_api.regional.id
}

output "api_gateway_domain" {
  description = "Regional API Gateway domain"
  value       = aws_apigatewayv2_domain_name.regional.domain_name
}

output "api_gateway_zone_id" {
  description = "Regional API Gateway zone ID"
  value       = aws_apigatewayv2_domain_name.regional.domain_name_configuration[0].hosted_zone_id
}

output "waf_web_acl_arn" {
  description = "Regional WAF Web ACL ARN"
  value       = aws_wafv2_web_acl.regional.arn
}

output "certificate_arn" {
  description = "Regional certificate ARN"
  value       = aws_acm_certificate.regional.arn
}