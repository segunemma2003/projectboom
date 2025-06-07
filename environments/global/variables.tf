variable "project_name" {
  description = "Project name"
  type        = string
  default     = "social-platform"
}

variable "domain_name" {
  description = "Primary domain name"
  type        = string
}

variable "primary_api_endpoint" {
  description = "Primary region API endpoint"
  type        = string
}

variable "primary_alb_dns_name" {
  description = "Primary region ALB DNS name"
  type        = string
}

# Regional configuration
variable "regional_endpoints" {
  description = "Map of regional API endpoints"
  type        = map(string)
  default = {
    "eu-west-1"      = ""
    "us-east-1"      = ""
    "ap-southeast-1" = ""
  }
}

# Edge routing configuration
variable "enable_edge_routing" {
  description = "Enable Lambda@Edge geographical routing"
  type        = bool
  default     = true
}

# WAF configuration
variable "global_rate_limit" {
  description = "Global rate limit per IP (requests per 5 minutes)"
  type        = number
  default     = 5000
}

# CloudFront configuration
variable "cloudfront_price_class" {
  description = "CloudFront price class"
  type        = string
  default     = "PriceClass_All"
  
  validation {
    condition = contains([
      "PriceClass_100",
      "PriceClass_200", 
      "PriceClass_All"
    ], var.cloudfront_price_class)
    error_message = "CloudFront price class must be PriceClass_100, PriceClass_200, or PriceClass_All."
  }
}

# Monitoring and alerting
variable "global_alert_emails" {
  description = "Email addresses for global infrastructure alerts"
  type        = list(string)
  default     = []
}

variable "enable_detailed_monitoring" {
  description = "Enable detailed CloudWatch monitoring"
  type        = bool
  default     = true
}

# Backup and disaster recovery
variable "backup_retention_days" {
  description = "Backup retention period in days"
  type        = number
  default     = 365
}

variable "enable_cross_region_backup" {
  description = "Enable cross-region backup replication"
  type        = bool
  default     = true
}

# Cost management
variable "global_monthly_budget_limit" {
  description = "Global monthly budget limit in USD"
  type        = number
  default     = 20000
}

variable "enable_cost_optimization" {
  description = "Enable cost optimization features"
  type        = bool
  default     = true
}

# Security configuration
variable "allowed_countries" {
  description = "List of allowed country codes (ISO 3166-1 alpha-2). Empty list means all countries allowed."
  type        = list(string)
  default     = []
}

variable "blocked_countries" {
  description = "List of blocked country codes (ISO 3166-1 alpha-2)"
  type        = list(string)
  default     = []
}

# SSL/TLS configuration
variable "minimum_protocol_version" {
  description = "Minimum TLS protocol version for CloudFront"
  type        = string
  default     = "TLSv1.2_2021"
  
  validation {
    condition = contains([
      "TLSv1",
      "TLSv1_2016",
      "TLSv1.1_2016",
      "TLSv1.2_2018",
      "TLSv1.2_2019",
      "TLSv1.2_2021"
    ], var.minimum_protocol_version)
    error_message = "Invalid TLS protocol version specified."
  }
}

# Cache configuration
variable "default_cache_ttl" {
  description = "Default cache TTL in seconds"
  type        = number
  default     = 3600
}

variable "max_cache_ttl" {
  description = "Maximum cache TTL in seconds"
  type        = number
  default     = 86400
}

variable "static_content_ttl" {
  description = "Cache TTL for static content in seconds"
  type        = number
  default     = 86400
}

variable "media_content_ttl" {
  description = "Cache TTL for media content in seconds"
  type        = number
  default     = 604800
}

# Health check configuration
variable "health_check_interval" {
  description = "Route 53 health check interval in seconds"
  type        = number
  default     = 30
  
  validation {
    condition     = contains([10, 30], var.health_check_interval)
    error_message = "Health check interval must be 10 or 30 seconds."
  }
}

variable "health_check_failure_threshold" {
  description = "Number of consecutive health check failures before marking unhealthy"
  type        = number
  default     = 3
  
  validation {
    condition     = var.health_check_failure_threshold >= 1 && var.health_check_failure_threshold <= 10
    error_message = "Health check failure threshold must be between 1 and 10."
  }
}

# Performance configuration
variable "enable_compression" {
  description = "Enable CloudFront compression"
  type        = bool
  default     = true
}

variable "enable_ipv6" {
  description = "Enable IPv6 for CloudFront distribution"
  type        = bool
  default     = true
}

# Tags
variable "additional_tags" {
  description = "Additional tags to apply to resources"
  type        = map(string)
  default     = {}
}