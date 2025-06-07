variable "websocket_port" {
  description = "WebSocket port"
  type        = number
  default     = 8001
}

variable "database_instance_class" {
  description = "RDS instance class"
  type        = string
  default     = "db.r6g.large"
}

variable "database_allocated_storage" {
  description = "RDS allocated storage"
  type        = number
  default     = 100
}

variable "database_max_allocated_storage" {
  description = "RDS max allocated storage"
  type        = number
  default     = 1000
}

variable "database_backup_retention_period" {
  description = "RDS backup retention period"
  type        = number
  default     = 7
}

variable "database_multi_az" {
  description = "Enable RDS Multi-AZ"
  type        = bool
  default     = true
}

variable "redis_node_type" {
  description = "ElastiCache node type"
  type        = string
  default     = "cache.r7g.large"
}

variable "redis_num_cache_nodes" {
  description = "Number of cache nodes"
  type        = number
  default     = 3
}

variable "ecr_repository_url" {
  description = "ECR repository URL"
  type        = string
}

variable "api_cpu" {
  description = "API task CPU"
  type        = number
  default     = 1024
}

variable "api_memory" {
  description = "API task memory"
  type        = number
  default     = 2048
}

variable "api_desired_count" {
  description = "API desired count"
  type        = number
  default     = 3
}

variable "websocket_cpu" {
  description = "WebSocket task CPU"
  type        = number
  default     = 512
}

variable "websocket_memory" {
  description = "WebSocket task memory"
  type        = number
  default     = 1024
}

variable "websocket_desired_count" {
  description = "WebSocket desired count"
  type        = number
  default     = 2
}

variable "autoscaling_min_capacity" {
  description = "Minimum auto scaling capacity"
  type        = number
  default     = 2
}

variable "autoscaling_max_capacity" {
  description = "Maximum auto scaling capacity"
  type        = number
  default     = 50
}

variable "alert_email" {
  description = "Email for alerts"
  type        = string
}

variable "slack_webhook_url" {
  description = "Slack webhook URL for alerts"
  type        = string
  default     = ""
}
