variable "aws_region" {
  description = "AWS region"
  type        = string
  default     = "eu-west-1"
}

variable "environment" {
  description = "Environment name"
  type        = string
  default     = "production"
}

variable "project_name" {
  description = "Project name"
  type        = string
  default     = "social-platform"
}

variable "owner" {
  description = "Project owner"
  type        = string
  default     = "platform-team"
}

# Networking Variables
variable "vpc_cidr" {
  description = "CIDR block for VPC"
  type        = string
  default     = "10.0.0.0/16"
}

variable "enable_nat_gateway" {
  description = "Enable NAT Gateway for private subnets"
  type        = bool
  default     = true
}

# Application Variables
variable "domain_name" {
  description = "Domain name for the application"
  type        = string
}

variable "route53_zone_id" {
  description = "Route 53 hosted zone ID"
  type        = string
}

variable "app_port" {
  description = "Application port"
  type        = number
  default     = 8000
}

variable "websocket_port" {
  description = "WebSocket port"
  type        = number
  default     = 8001
}

# Database Variables
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

# Redis Variables
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

# ECS Variables
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

# Auto Scaling Variables
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

# Monitoring Variables
variable "alert_email" {
  description = "Email for alerts"
  type        = string
}

variable "slack_webhook_url" {
  description = "Slack webhook URL for alerts"
  type        = string
  default     = ""
}