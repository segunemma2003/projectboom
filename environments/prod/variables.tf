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

variable "domain_name" {
  description = "Domain name for the application"
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

# Enhanced Aurora Database Configuration
variable "database_writer_count" {
  description = "Number of Aurora writer instances"
  type        = number
  default     = 3
}

variable "database_reader_count" {
  description = "Number of Aurora reader instances"
  type        = number
  default     = 8
}

variable "database_min_capacity" {
  description = "Aurora Serverless v2 minimum capacity"
  type        = number
  default     = 4
}

variable "database_max_capacity" {
  description = "Aurora Serverless v2 maximum capacity"
  type        = number
  default     = 256
}

variable "database_backup_retention_period" {
  description = "RDS backup retention period"
  type        = number
  default     = 14
}

variable "database_deletion_protection" {
  description = "Enable database deletion protection"
  type        = bool
  default     = true
}

variable "enable_global_cluster" {
  description = "Enable Aurora Global Cluster for disaster recovery"
  type        = bool
  default     = true
}

# Enhanced Redis Cluster Configuration
variable "redis_node_type" {
  description = "ElastiCache node type for main cluster"
  type        = string
  default     = "cache.r7g.2xlarge"
}

variable "redis_num_node_groups" {
  description = "Number of Redis node groups (shards) for main cluster"
  type        = number
  default     = 8
}

variable "redis_replicas_per_node_group" {
  description = "Number of replica nodes per node group"
  type        = number
  default     = 3
}

variable "redis_session_node_type" {
  description = "ElastiCache node type for session cluster"
  type        = string
  default     = "cache.r7g.xlarge"
}

variable "redis_session_num_node_groups" {
  description = "Number of node groups for session cluster"
  type        = number
  default     = 4
}

variable "redis_realtime_node_type" {
  description = "ElastiCache node type for real-time cluster"
  type        = string
  default     = "cache.r7g.2xlarge"
}

variable "redis_realtime_num_node_groups" {
  description = "Number of node groups for real-time cluster"
  type        = number
  default     = 6
}

variable "ecr_repository_url" {
  description = "ECR repository URL"
  type        = string
}

# Enhanced API Service Configuration
variable "api_cpu" {
  description = "API task CPU"
  type        = number
  default     = 2048
}

variable "api_memory" {
  description = "API task memory"
  type        = number
  default     = 4096
}

variable "api_desired_count" {
  description = "API desired count"
  type        = number
  default     = 15
}

# Enhanced WebSocket Service Configuration
variable "websocket_cpu" {
  description = "WebSocket task CPU"
  type        = number
  default     = 1024
}

variable "websocket_memory" {
  description = "WebSocket task memory"
  type        = number
  default     = 2048
}

variable "websocket_desired_count" {
  description = "WebSocket desired count"
  type        = number
  default     = 10
}

# LiveKit Configuration
variable "livekit_cpu" {
  description = "LiveKit task CPU"
  type        = number
  default     = 4096
}

variable "livekit_memory" {
  description = "LiveKit task memory"
  type        = number
  default     = 8192
}

variable "livekit_desired_count" {
  description = "LiveKit desired count"
  type        = number
  default     = 8
}

variable "livekit_min_capacity" {
  description = "LiveKit minimum capacity"
  type        = number
  default     = 5
}

variable "livekit_max_capacity" {
  description = "LiveKit maximum capacity"
  type        = number
  default     = 25
}

variable "enable_livekit_recording" {
  description = "Enable LiveKit recording"
  type        = bool
  default     = true
}

# Auto Scaling Configuration
variable "autoscaling_min_capacity" {
  description = "Minimum auto scaling capacity"
  type        = number
  default     = 5
}

variable "autoscaling_max_capacity" {
  description = "Maximum auto scaling capacity"
  type        = number
  default     = 100
}

# API Gateway Rate Limiting (for 40M users)
variable "api_throttle_burst_limit" {
  description = "API Gateway throttle burst limit"
  type        = number
  default     = 10000
}

variable "api_throttle_rate_limit" {
  description = "API Gateway throttle rate limit"
  type        = number
  default     = 5000
}

variable "waf_rate_limit" {
  description = "WAF rate limit per IP (requests per 5 minutes)"
  type        = number
  default     = 2000
}

# Usage Plan Configuration
variable "premium_quota_limit" {
  description = "Premium plan daily quota limit"
  type        = number
  default     = 1000000
}

variable "premium_throttle_burst_limit" {
  description = "Premium plan throttle burst limit"
  type        = number
  default     = 10000
}

variable "premium_throttle_rate_limit" {
  description = "Premium plan throttle rate limit"
  type        = number
  default     = 5000
}

variable "standard_quota_limit" {
  description = "Standard plan daily quota limit"
  type        = number
  default     = 100000
}

variable "standard_throttle_burst_limit" {
  description = "Standard plan throttle burst limit"
  type        = number
  default     = 2000
}

variable "standard_throttle_rate_limit" {
  description = "Standard plan throttle rate limit"
  type        = number
  default     = 1000
}

# Business Metrics Thresholds (for 40M users)
variable "min_active_users_threshold" {
  description = "Minimum active users threshold for alarm"
  type        = number
  default     = 100000
}

variable "max_video_calls_threshold" {
  description = "Maximum concurrent video calls threshold"
  type        = number
  default     = 50000
}

variable "max_message_queue_length" {
  description = "Maximum message queue length threshold"
  type        = number
  default     = 100000
}

variable "max_database_connections" {
  description = "Maximum database connections threshold"
  type        = number
  default     = 8000
}

# Cost and Monitoring Configuration
variable "enable_cost_monitoring" {
  description = "Enable cost monitoring alarms"
  type        = bool
  default     = true
}

variable "cost_alert_threshold" {
  description = "Cost alert threshold in USD per month"
  type        = number
  default     = 50000
}

variable "enable_custom_metrics" {
  description = "Enable custom business metrics collection"
  type        = bool
  default     = true
}

variable "critical_alert_emails" {
  description = "Email addresses for critical alerts"
  type        = list(string)
  default     = []
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