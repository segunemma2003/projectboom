variable "name_prefix" {
  description = "Name prefix for resources"
  type        = string
}

variable "environment" {
  description = "Environment name (development, staging, production)"
  type        = string
}

variable "project_name" {
  description = "Project name"
  type        = string
}

variable "aws_region" {
  description = "AWS region"
  type        = string
  default     = "eu-west-1"
}

# Budget variables
variable "monthly_budget_limit" {
  description = "Monthly budget limit in USD"
  type        = number
  default     = 10000
}

variable "compute_budget_limit" {
  description = "Compute budget limit in USD"
  type        = number
  default     = 4000
}

variable "database_budget_limit" {
  description = "Database budget limit in USD"
  type        = number
  default     = 3000
}

# Alert configuration
variable "budget_alert_emails" {
  description = "Email addresses for budget alerts"
  type        = list(string)
  default     = []
}

variable "cost_alert_emails" {
  description = "Email addresses for cost alerts"
  type        = list(string)
  default     = []
}

variable "critical_alert_emails" {
  description = "Email addresses for critical cost alerts"
  type        = list(string)
  default     = []
}

variable "cost_anomaly_email" {
  description = "Email address for cost anomaly alerts"
  type        = string
  default     = ""
}

# Integration variables
variable "slack_webhook_url" {
  description = "Slack webhook URL for cost notifications"
  type        = string
  default     = ""
}

variable "autoscaling_group_name" {
  description = "Auto Scaling Group name for scheduling"
  type        = string
  default     = ""
}

variable "tags" {
  description = "Tags to apply to resources"
  type        = map(string)
  default     = {}
}