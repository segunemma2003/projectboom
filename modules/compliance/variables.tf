variable "name_prefix" {
  description = "Name prefix for resources"
  type        = string
}

variable "environment" {
  description = "Environment name (development, staging, production)"
  type        = string
}

variable "vpc_id" {
  description = "VPC ID for Lambda functions"
  type        = string
}

variable "subnet_ids" {
  description = "Subnet IDs for Lambda functions"
  type        = list(string)
}

variable "domain_name" {
  description = "Domain name for the application"
  type        = string
}

# Data scanning configuration
variable "s3_buckets_for_scanning" {
  description = "List of S3 bucket names for Macie data classification"
  type        = list(string)
  default     = []
}

variable "user_data_s3_buckets" {
  description = "List of S3 bucket names containing user data"
  type        = list(string)
  default     = []
}

# Database table references
variable "chat_messages_table_name" {
  description = "Name of the chat messages DynamoDB table"
  type        = string
  default     = ""
}

variable "user_profiles_table_name" {
  description = "Name of the user profiles DynamoDB table"
  type        = string
  default     = ""
}

# Notification configuration
variable "compliance_notification_emails" {
  description = "Email addresses for compliance notifications"
  type        = list(string)
  default     = []
}

# Data retention policies
variable "data_retention_policies" {
  description = "Map of data retention policies"
  type        = map(string)
  default = {
    chat_messages = "2years"
    user_profiles = "inactive_3years"
    audit_logs    = "7years"
    media_files   = "user_controlled"
  }
}

# Glue job configuration
variable "scripts_bucket" {
  description = "S3 bucket name for Glue scripts"
  type        = string
  default     = ""
}

variable "temp_bucket" {
  description = "S3 bucket name for temporary Glue files"
  type        = string
  default     = ""
}

variable "source_database_name" {
  description = "Source database name for data anonymization"
  type        = string
  default     = ""
}

variable "anonymized_database_name" {
  description = "Target database name for anonymized data"
  type        = string
  default     = ""
}

# Monitoring configuration
variable "enable_compliance_monitoring" {
  description = "Enable compliance monitoring and alerting"
  type        = bool
  default     = true
}

variable "data_request_error_threshold" {
  description = "Threshold for data request processing errors alarm"
  type        = number
  default     = 5
}

variable "data_request_duration_threshold" {
  description = "Threshold for data request processing duration alarm (milliseconds)"
  type        = number
  default     = 600000
}

# Lambda configuration
variable "lambda_timeout" {
  description = "Lambda function timeout in seconds"
  type        = number
  default     = 900
}

variable "lambda_reserved_concurrency" {
  description = "Reserved concurrency for Lambda functions"
  type        = number
  default     = 10
}

# API Gateway configuration
variable "api_log_retention_days" {
  description = "CloudWatch log retention for API Gateway"
  type        = number
  default     = 14
}

variable "enable_api_gateway_logging" {
  description = "Enable detailed API Gateway logging"
  type        = bool
  default     = true
}

# GDPR compliance settings
variable "gdpr_audit_retention_years" {
  description = "Number of years to retain GDPR audit logs"
  type        = number
  default     = 7
}

variable "consent_retention_years" {
  description = "Number of years to retain user consent records"
  type        = number
  default     = 7
}

variable "enable_macie_scanning" {
  description = "Enable Amazon Macie for data classification"
  type        = bool
  default     = true
}

variable "macie_finding_frequency" {
  description = "Macie finding publishing frequency"
  type        = string
  default     = "FIFTEEN_MINUTES"
  
  validation {
    condition = contains([
      "FIFTEEN_MINUTES",
      "ONE_HOUR",
      "SIX_HOURS"
    ], var.macie_finding_frequency)
    error_message = "Macie finding frequency must be FIFTEEN_MINUTES, ONE_HOUR, or SIX_HOURS."
  }
}

# Data subject rights configuration
variable "max_data_export_size_gb" {
  description = "Maximum size for data exports in GB"
  type        = number
  default     = 10
}

variable "data_request_sla_hours" {
  description = "SLA for data subject rights requests in hours"
  type        = number
  default     = 72
}

# Encryption configuration
variable "enable_encryption_at_rest" {
  description = "Enable encryption at rest for all compliance data"
  type        = bool
  default     = true
}

variable "kms_key_rotation" {
  description = "Enable automatic KMS key rotation"
  type        = bool
  default     = true
}

# Tags
variable "tags" {
  description = "Tags to apply to resources"
  type        = map(string)
  default     = {}
}