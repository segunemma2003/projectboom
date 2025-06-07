output "api_gateway_id" {
  description = "API Gateway v2 API ID"
  value       = aws_apigatewayv2_api.main.id
}

output "api_gateway_execution_arn" {
  description = "API Gateway execution ARN"
  value       = aws_apigatewayv2_api.main.execution_arn
}

output "api_gateway_endpoint" {
  description = "API Gateway endpoint URL"
  value       = aws_apigatewayv2_api.main.api_endpoint
}

output "api_gateway_custom_domain" {
  description = "API Gateway custom domain name"
  value       = aws_apigatewayv2_domain_name.main.domain_name
}

output "api_gateway_regional_domain_name" {
  description = "API Gateway regional domain name"
  value       = aws_apigatewayv2_domain_name.main.domain_name_configuration[0].target_domain_name
}

output "api_gateway_regional_zone_id" {
  description = "API Gateway regional zone ID"
  value       = aws_apigatewayv2_domain_name.main.domain_name_configuration[0].hosted_zone_id
}

output "websocket_api_id" {
  description = "WebSocket API ID"
  value       = aws_apigatewayv2_api.websocket.id
}

output "websocket_api_endpoint" {
  description = "WebSocket API endpoint"
  value       = aws_apigatewayv2_api.websocket.api_endpoint
}

output "vpc_link_id" {
  description = "VPC Link ID"
  value       = aws_apigatewayv2_vpc_link.main.id
}

output "waf_web_acl_arn" {
  description = "WAF Web ACL ARN"
  value       = aws_wafv2_web_acl.api_gateway.arn
}

output "stage_invoke_url" {
  description = "Stage invoke URL"
  value       = aws_apigatewayv2_stage.main.invoke_url
}