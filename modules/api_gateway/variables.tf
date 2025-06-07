variable "name_prefix" {
  description = "Name prefix for resources"
  type        = string
}

variable "vpc_id" {
  description = "VPC ID"
  type        = string
}

variable "private_subnet_ids" {
  description = "Private subnet IDs"
  type        = list(string)
}

variable "domain_name" {
  description = "Domain name"
  type        = string
}

variable "certificate_arn" {
  description = "ACM certificate ARN"
  type        = string
}

variable "environment" {
  description = "Environment name"
  type        = string
}

variable "alb_listener_arn" {
  description = "ALB listener ARN"
  type        = string
}

variable "alb_dns_name" {
  description = "ALB DNS name"
  type        = string
}

variable "cors_origins" {
  description = "CORS allowed origins"
  type        = list(string)
  default     = ["*"]
}

# Rate limiting - Note: API Gateway v2 handles throttling differently
variable "throttle_burst_limit" {
  description = "API Gateway throttle burst limit (for reference only)"
  type        = number
  default     = 5000
}

variable "throttle_rate_limit" {
  description = "API Gateway throttle rate limit (for reference only)"
  type        = number
  default     = 2000
}

variable "websocket_throttle_burst_limit" {
  description = "WebSocket throttle burst limit (for reference only)"
  type        = number
  default     = 1000
}

variable "websocket_throttle_rate_limit" {
  description = "WebSocket throttle rate limit (for reference only)"
  type        = number
  default     = 500
}

variable "waf_rate_limit" {
  description = "WAF rate limit per IP (requests per 5 minutes)"
  type        = number
  default     = 2000
}

# These variables are kept for compatibility but not used in v2
variable "premium_quota_limit" {
  description = "Premium plan daily quota limit (v1 compatibility)"
  type        = number
  default     = 1000000
}

variable "premium_throttle_burst_limit" {
  description = "Premium plan throttle burst limit (v1 compatibility)"
  type        = number
  default     = 10000
}

variable "premium_throttle_rate_limit" {
  description = "Premium plan throttle rate limit (v1 compatibility)"
  type        = number
  default     = 5000
}

variable "standard_quota_limit" {
  description = "Standard plan daily quota limit (v1 compatibility)"
  type        = number
  default     = 100000
}

variable "standard_throttle_burst_limit" {
  description = "Standard plan throttle burst limit (v1 compatibility)"
  type        = number
  default     = 2000
}

variable "standard_throttle_rate_limit" {
  description = "Standard plan throttle rate limit (v1 compatibility)"
  type        = number
  default     = 1000
}

variable "enable_route_throttling" {
  description = "Enable route-level throttling for specific endpoints"
  type        = bool
  default     = false
}

variable "log_retention_days" {
  description = "CloudWatch logs retention period"
  type        = number
  default     = 7
}

variable "alarm_actions" {
  description = "SNS topic ARNs for alarm actions"
  type        = list(string)
  default     = []
}

variable "tags" {
  description = "Tags to apply to resources"
  type        = map(string)
  default     = {}
}
