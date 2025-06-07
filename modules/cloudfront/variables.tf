variable "name_prefix" {
  description = "Name prefix for resources"
  type        = string
}

variable "domain_name" {
  description = "Domain name"
  type        = string
}

variable "s3_bucket_domain" {
  description = "S3 bucket domain name"
  type        = string
}

variable "alb_domain_name" {
  description = "ALB domain name"
  type        = string
}

variable "certificate_arn" {
  description = "ACM certificate ARN"
  type        = string
}

variable "tags" {
  description = "Tags to apply to resources"
  type        = map(string)
  default     = {}
}
