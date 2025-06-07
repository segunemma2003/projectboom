variable "name_prefix" {
  description = "Name prefix for resources"
  type        = string
}

variable "cluster_name" {
  description = "ECS cluster name"
  type        = string
}

variable "environment" {
  description = "Environment name"
  type        = string
}

variable "aws_region" {
  description = "AWS region"
  type        = string
  default     = "us-west-2"
}

variable "log_retention_days" {
  description = "CloudWatch logs retention period"
  type        = number
  default     = 7
}

variable "enable_custom_metrics" {
  description = "Enable custom CloudWatch dashboard"
  type        = bool
  default     = false
}

# Enhanced monitoring variables
variable "alb_full_name" {
  description = "Full name of the Application Load Balancer"
  type        = string
  default     = ""
}

variable "database_cluster_name" {
  description = "Aurora database cluster name"
  type        = string
  default     = ""
}

variable "redis_endpoint" {
  description = "Redis cluster endpoint"
  type        = string
  default     = ""
}

# Business metrics thresholds
variable "min_active_users_threshold" {
  description = "Minimum active users threshold for alarm"
  type        = number
  default     = 1000
}

variable "max_video_calls_threshold" {
  description = "Maximum concurrent video calls threshold"
  type        = number
  default     = 1000
}

variable "max_message_queue_length" {
  description = "Maximum message queue length threshold"
  type        = number
  default     = 10000
}

variable "max_database_connections" {
  description = "Maximum database connections threshold"
  type        = number
  default     = 1000
}

# Cost monitoring
variable "enable_cost_monitoring" {
  description = "Enable cost monitoring alarms"
  type        = bool
  default     = false
}

variable "cost_alert_threshold" {
  description = "Cost alert threshold in USD per month"
  type        = number
  default     = 1000
}

variable "critical_alert_emails" {
  description = "Email addresses for critical alerts"
  type        = list(string)
  default     = []
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