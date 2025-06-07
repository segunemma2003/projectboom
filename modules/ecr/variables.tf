variable "name_prefix" {
  description = "Name prefix for ECR repositories"
  type        = string
}

variable "repository_names" {
  description = "List of repository names to create"
  type        = list(string)
  default     = ["api", "websocket", "livekit", "content-moderation", "media-processor"]
}

variable "image_tag_mutability" {
  description = "Image tag mutability setting"
  type        = string
  default     = "MUTABLE"
  
  validation {
    condition     = contains(["MUTABLE", "IMMUTABLE"], var.image_tag_mutability)
    error_message = "Image tag mutability must be either MUTABLE or IMMUTABLE."
  }
}

variable "scan_on_push" {
  description = "Enable vulnerability scanning on image push"
  type        = bool
  default     = true
}

variable "max_image_count" {
  description = "Maximum number of production images to keep"
  type        = number
  default     = 30
}

variable "max_dev_image_count" {
  description = "Maximum number of development images to keep"
  type        = number
  default     = 10
}

variable "untagged_image_days" {
  description = "Number of days to keep untagged images"
  type        = number
  default     = 1
}

variable "enable_cross_region_replication" {
  description = "Enable cross-region replication for disaster recovery"
  type        = bool
  default     = true
}

variable "replication_region" {
  description = "Target region for replication"
  type        = string
  default     = "us-east-1"
}

variable "enable_pull_through_cache" {
  description = "Enable pull-through cache for upstream registries"
  type        = bool
  default     = true
}

variable "log_retention_days" {
  description = "CloudWatch logs retention period"
  type        = number
  default     = 14
}

variable "repository_size_alarm_threshold" {
  description = "Repository size alarm threshold in bytes"
  type        = number
  default     = 10737418240  # 10 GB
}

variable "notification_emails" {
  description = "Email addresses for ECR notifications"
  type        = list(string)
  default     = []
}

variable "tags" {
  description = "Tags to apply to resources"
  type        = map(string)
  default     = {}
}