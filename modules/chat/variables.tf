variable "name_prefix" {
  description = "Name prefix for resources"
  type        = string
}

variable "environment" {
  description = "Environment name"
  type        = string
}

variable "aws_region" {
  description = "AWS region"
  type        = string
}

variable "vpc_id" {
  description = "VPC ID for Lambda functions"
  type        = string
  default     = ""
}

variable "subnet_ids" {
  description = "Subnet IDs for Lambda functions"
  type        = list(string)
  default     = []
}

variable "redis_realtime_endpoint" {
  description = "Redis endpoint for real-time data"
  type        = string
}

variable "enable_message_ttl" {
  description = "Enable automatic message deletion with TTL"
  type        = bool
  default     = false
}

variable "use_customer_managed_kms" {
  description = "Use customer-managed KMS key (requires PROVISIONED billing mode)"
  type        = bool
  default     = false
}

variable "lambda_reserved_concurrency" {
  description = "Reserved concurrency for Lambda functions"
  type        = number
  default     = 100
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