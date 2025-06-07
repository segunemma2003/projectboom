variable "name_prefix" {
  description = "Name prefix for resources"
  type        = string
}

variable "domain_name" {
  description = "Domain name for the hosted zone"
  type        = string
}

variable "aws_region" {
  description = "AWS region"
  type        = string
  default     = "eu-west-1"
}

variable "enable_health_checks" {
  description = "Enable Route 53 health checks"
  type        = bool
  default     = true
}

variable "enable_failover" {
  description = "Enable failover routing"
  type        = bool
  default     = false
}

variable "enable_geo_routing" {
  description = "Enable geolocation routing"
  type        = bool
  default     = false
}

variable "primary_endpoint" {
  description = "Primary endpoint for health checks"
  type        = string
  default     = ""
}

variable "secondary_endpoint" {
  description = "Secondary endpoint for health checks"
  type        = string
  default     = ""
}

variable "secondary_region" {
  description = "Secondary region for health checks"
  type        = string
  default     = "us-east-1"
}

variable "primary_alb_dns" {
  description = "Primary ALB DNS name"
  type        = string
  default     = ""
}

variable "primary_alb_zone_id" {
  description = "Primary ALB zone ID"
  type        = string
  default     = ""
}

variable "secondary_alb_dns" {
  description = "Secondary ALB DNS name"
  type        = string
  default     = ""
}

variable "secondary_alb_zone_id" {
  description = "Secondary ALB zone ID"
  type        = string
  default     = ""
}

variable "us_alb_dns" {
  description = "US region ALB DNS name"
  type        = string
  default     = ""
}

variable "us_alb_zone_id" {
  description = "US region ALB zone ID"
  type        = string
  default     = ""
}

variable "eu_alb_dns" {
  description = "EU region ALB DNS name"
  type        = string
  default     = ""
}

variable "eu_alb_zone_id" {
  description = "EU region ALB zone ID"
  type        = string
  default     = ""
}

variable "ap_alb_dns" {
  description = "AP region ALB DNS name"
  type        = string
  default     = ""
}

variable "ap_alb_zone_id" {
  description = "AP region ALB zone ID"
  type        = string
  default     = ""
}

variable "tags" {
  description = "Tags to apply to resources"
  type        = map(string)
  default     = {}
}
