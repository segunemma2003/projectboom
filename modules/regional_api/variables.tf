variable "name_prefix" {
  description = "Name prefix for resources"
  type        = string
}

variable "region_name" {
  description = "AWS region name"
  type        = string
}

variable "domain_name" {
  description = "Primary domain name"
  type        = string
}

variable "primary_api_endpoint" {
  description = "Primary region API endpoint"
  type        = string
}

variable "global_certificate_arn" {
  description = "Global certificate ARN (from us-east-1)"
  type        = string
}

variable "health_check_path" {
  description = "Health check endpoint path"
  type        = string
  default     = "/health/"
}

variable "allowed_countries" {
  description = "List of allowed country codes (ISO 3166-1 alpha-2)"
  type        = list(string)
  default     = null
}

variable "blocked_countries" {
  description = "List of blocked country codes (ISO 3166-1 alpha-2)"
  type        = list(string)
  default     = []
}

variable "rate_limit" {
  description = "Rate limit for regional API"
  type        = number
  default     = 1000
}

variable "tags" {
  description = "Tags to apply to resources"
  type        = map(string)
  default     = {}
}