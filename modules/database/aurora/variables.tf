variable "name_prefix" {
  description = "Name prefix for resources"
  type        = string
}

variable "vpc_id" {
  description = "VPC ID"
  type        = string
}

variable "subnet_ids" {
  description = "Subnet IDs for database"
  type        = list(string)
}

variable "security_group_ids" {
  description = "Security group IDs"
  type        = list(string)
}

variable "writer_count" {
  description = "Number of writer instances"
  type        = number
  default     = 1
}

variable "reader_count" {
  description = "Number of reader instances"
  type        = number
  default     = 1
}

variable "min_capacity" {
  description = "Minimum Aurora Serverless v2 capacity"
  type        = number
  default     = 0.5
}

variable "max_capacity" {
  description = "Maximum Aurora Serverless v2 capacity"
  type        = number
  default     = 1
}

variable "backup_retention_period" {
  description = "Backup retention period in days"
  type        = number
  default     = 7
}

variable "deletion_protection" {
  description = "Enable deletion protection"
  type        = bool
  default     = true
}

variable "enable_global_cluster" {
  description = "Enable Aurora Global Cluster"
  type        = bool
  default     = false
}

variable "monitoring_role_arn" {
  description = "RDS monitoring role ARN"
  type        = string
}

variable "proxy_role_arn" {
  description = "RDS Proxy role ARN"
  type        = string
}

variable "tags" {
  description = "Tags to apply to resources"
  type        = map(string)
  default     = {}
}