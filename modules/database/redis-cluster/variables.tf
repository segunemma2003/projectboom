variable "name_prefix" {
  description = "Name prefix for resources"
  type        = string
}

variable "vpc_id" {
  description = "VPC ID"
  type        = string
}

variable "subnet_ids" {
  description = "Subnet IDs for Redis cluster"
  type        = list(string)
}

variable "security_group_ids" {
  description = "Security group IDs"
  type        = list(string)
}

# Main cluster configuration
variable "node_type" {
  description = "ElastiCache node type for main cluster"
  type        = string
  default     = "cache.r7g.2xlarge"
}

variable "num_node_groups" {
  description = "Number of node groups (shards) for main cluster"
  type        = number
  default     = 6
}

variable "replicas_per_node_group" {
  description = "Number of replica nodes per node group"
  type        = number
  default     = 2
}

# Session cluster configuration
variable "session_node_type" {
  description = "ElastiCache node type for session cluster"
  type        = string
  default     = "cache.r7g.large"
}

variable "session_num_node_groups" {
  description = "Number of node groups for session cluster"
  type        = number
  default     = 3
}

# Real-time cluster configuration
variable "realtime_node_type" {
  description = "ElastiCache node type for real-time cluster"
  type        = string
  default     = "cache.r7g.xlarge"
}

variable "realtime_num_node_groups" {
  description = "Number of node groups for real-time cluster"
  type        = number
  default     = 4
}

variable "auth_token_enabled" {
  description = "Enable auth token for Redis clusters"
  type        = bool
  default     = true
}

variable "snapshot_retention_limit" {
  description = "Number of days to retain automatic snapshots"
  type        = number
  default     = 7
}

variable "log_retention_days" {
  description = "CloudWatch log retention in days"
  type        = number
  default     = 14
}

variable "notification_topic_arn" {
  description = "SNS topic ARN for notifications"
  type        = string
  default     = ""
}

variable "alarm_actions" {
  description = "List of ARNs to notify when alarm triggers"
  type        = list(string)
  default     = []
}

variable "tags" {
  description = "Tags to apply to resources"
  type        = map(string)
  default     = {}
}