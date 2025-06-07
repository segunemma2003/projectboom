variable "name_prefix" {
  description = "Name prefix for resources"
  type        = string
}

variable "environment" {
  description = "Environment name (development, staging, production)"
  type        = string
}

variable "aws_region" {
  description = "AWS region"
  type        = string
  default     = "eu-west-1"
}

variable "domain_name" {
  description = "Domain name for the application"
  type        = string
}

variable "redis_endpoint" {
  description = "Redis endpoint for caching and real-time features"
  type        = string
}

variable "websocket_api_endpoint" {
  description = "WebSocket API endpoint for real-time notifications"
  type        = string
  default     = ""
}

# Firebase Cloud Messaging (FCM) configuration
variable "fcm_server_key" {
  description = "Firebase Cloud Messaging server key for push notifications"
  type        = string
  default     = ""
  sensitive   = true
}

# Apple Push Notification Service (APNS) configuration
variable "apns_certificate_arn" {
  description = "ARN of APNS certificate in AWS Certificate Manager"
  type        = string
  default     = ""
}

# Email configuration
variable "from_email_address" {
  description = "From email address for sending notifications"
  type        = string
  default     = "noreply@example.com"
}

# SMS configuration
variable "sms_sender_id" {
  description = "SMS sender ID for SMS notifications"
  type        = string
  default     = "SocialApp"
}

# Notification processing configuration
variable "max_notification_batch_size" {
  description = "Maximum batch size for notification processing"
  type        = number
  default     = 50
}

variable "rate_limit_per_user" {
  description = "Rate limit per user per hour for notifications"
  type        = number
  default     = 100
}

variable "lambda_concurrent_executions" {
  description = "Reserved concurrent executions for Lambda functions"
  type        = number
  default     = 50
}

# Monitoring configuration
variable "alarm_actions" {
  description = "SNS topic ARNs for alarm actions"
  type        = list(string)
  default     = []
}

variable "log_retention_days" {
  description = "CloudWatch logs retention period in days"
  type        = number
  default     = 14
}

# Advanced notification features
variable "enable_notification_analytics" {
  description = "Enable notification analytics and tracking"
  type        = bool
  default     = true
}

variable "enable_delivery_receipts" {
  description = "Enable delivery receipt tracking"
  type        = bool
  default     = true
}

variable "enable_user_preferences" {
  description = "Enable per-user notification preferences"
  type        = bool
  default     = true
}

variable "notification_ttl_hours" {
  description = "Time to live for notifications in hours"
  type        = number
  default     = 72
}

# Template configuration
variable "default_email_templates" {
  description = "Map of default email templates"
  type        = map(string)
  default = {
    welcome         = "welcome_template.html"
    password_reset  = "password_reset_template.html"
    notification    = "notification_template.html"
    weekly_digest   = "weekly_digest_template.html"
  }
}

# Push notification configuration
variable "push_notification_priority" {
  description = "Default priority for push notifications (high/normal)"
  type        = string
  default     = "normal"
  
  validation {
    condition     = contains(["high", "normal"], var.push_notification_priority)
    error_message = "Push notification priority must be either 'high' or 'normal'."
  }
}

variable "enable_quiet_hours" {
  description = "Enable quiet hours for notifications"
  type        = bool
  default     = true
}

variable "quiet_hours_start" {
  description = "Start time for quiet hours (24-hour format)"
  type        = string
  default     = "22:00"
}

variable "quiet_hours_end" {
  description = "End time for quiet hours (24-hour format)"
  type        = string
  default     = "08:00"
}

# Tags
variable "tags" {
  description = "Tags to apply to resources"
  type        = map(string)
  default     = {}
}