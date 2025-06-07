# Output values for reference
output "global_cloudfront_domain" {
  description = "Global CloudFront distribution domain"
  value       = aws_cloudfront_distribution.global.domain_name
}

output "primary_region_endpoints" {
  description = "Primary region endpoints"
  value = {
    load_balancer = module.primary_region.load_balancer_dns
    database      = module.primary_region.database_endpoint
    redis         = module.primary_region.redis_endpoint
  }
  sensitive = true
}

output "regional_api_endpoints" {
  description = "Regional API Gateway endpoints"
  value = {
    us_east      = module.regional_api_us_east.api_gateway_domain
    ap_southeast = module.regional_api_ap_southeast.api_gateway_domain
  }
}

output "health_check_ids" {
  description = "Route 53 health check IDs"
  value = {
    primary = aws_route53_health_check.primary.id
    us_east = aws_route53_health_check.us_east.id
  }
}