variable "name_prefix" {
  description = "Prefix for naming all resources"
  type        = string
  validation {
    condition     = can(regex("^[a-z0-9-]+$", var.name_prefix))
    error_message = "Name prefix must contain only lowercase letters, numbers, and hyphens."
  }
}

variable "environment" {
  description = "Environment name (e.g., dev, staging, prod)"
  type        = string
  default     = "dev"
}

variable "vpc_id" {
  description = "VPC ID where resources will be created"
  type        = string
}

variable "vpc_cidr" {
  description = "VPC CIDR block for security group rules"
  type        = string
}

variable "subnet_ids" {
  description = "List of subnet IDs for OpenSearch and Lambda functions"
  type        = list(string)
  validation {
    condition     = length(var.subnet_ids) >= 2
    error_message = "At least 2 subnet IDs must be provided for high availability."
  }
}

variable "domain_name" {
  description = "Domain name for CORS configuration"
  type        = string
}

# OpenSearch Configuration
variable "engine_version" {
  description = "OpenSearch engine version"
  type        = string
  default     = "OpenSearch_2.3"
}

variable "instance_type" {
  description = "Instance type for OpenSearch data nodes"
  type        = string
  default     = "t3.small.search"
}

variable "instance_count" {
  description = "Number of instances in the OpenSearch cluster"
  type        = number
  default     = 2
  validation {
    condition     = var.instance_count >= 1
    error_message = "Instance count must be at least 1."
  }
}

variable "dedicated_master_enabled" {
  description = "Whether to enable dedicated master nodes (AWS automatically configures instance type and count based on data node configuration)"
  type        = bool
  default     = false
}

variable "zone_awareness_enabled" {
  description = "Whether to enable zone awareness for OpenSearch"
  type        = bool
  default     = true
}

variable "availability_zone_count" {
  description = "Number of availability zones for zone awareness"
  type        = number
  default     = 2
  validation {
    condition     = contains([2, 3], var.availability_zone_count)
    error_message = "Availability zone count must be 2 or 3."
  }
}

# Warm Storage Configuration
variable "warm_enabled" {
  description = "Whether to enable warm storage"
  type        = bool
  default     = false
}

variable "warm_count" {
  description = "Number of warm nodes"
  type        = number
  default     = 2
}

variable "warm_type" {
  description = "Instance type for warm nodes"
  type        = string
  default     = "ultrawarm1.medium.search"
}

variable "cold_storage_enabled" {
  description = "Whether to enable cold storage"
  type        = bool
  default     = false
}

# EBS Configuration
variable "volume_type" {
  description = "EBS volume type (gp2, gp3, io1, io2)"
  type        = string
  default     = "gp3"
  validation {
    condition     = contains(["gp2", "gp3", "io1", "io2"], var.volume_type)
    error_message = "Volume type must be one of: gp2, gp3, io1, io2."
  }
}

variable "volume_size" {
  description = "EBS volume size in GB"
  type        = number
  default     = 20
  validation {
    condition     = var.volume_size >= 10 && var.volume_size <= 3584
    error_message = "Volume size must be between 10 and 3584 GB."
  }
}

variable "volume_iops" {
  description = "IOPS for gp3/io1/io2 volumes"
  type        = number
  default     = 3000
}

variable "volume_throughput" {
  description = "Throughput for gp3 volumes (MB/s)"
  type        = number
  default     = 125
}

# Security Configuration
variable "allowed_security_groups" {
  description = "List of security group IDs allowed to access OpenSearch"
  type        = list(string)
  default     = []
}

variable "fine_grained_access_control_enabled" {
  description = "Whether to enable fine-grained access control"
  type        = bool
  default     = true
}

variable "internal_user_database_enabled" {
  description = "Whether to enable internal user database"
  type        = bool
  default     = true
}

variable "master_user_name" {
  description = "Master username for OpenSearch"
  type        = string
  default     = "admin"
  sensitive   = true
}

variable "master_user_password" {
  description = "Master password for OpenSearch"
  type        = string
  sensitive   = true
  validation {
    condition     = length(var.master_user_password) >= 8
    error_message = "Master password must be at least 8 characters long."
  }
}

# Logging Configuration
variable "log_retention_days" {
  description = "CloudWatch log retention period in days"
  type        = number
  default     = 14
  validation {
    condition = contains([
      1, 3, 5, 7, 14, 30, 60, 90, 120, 150, 180, 365, 400, 545, 731, 1827, 3653
    ], var.log_retention_days)
    error_message = "Log retention days must be a valid CloudWatch retention period."
  }
}

# Lambda Configuration
variable "lambda_concurrent_executions" {
  description = "Reserved concurrent executions for Lambda functions"
  type        = number
  default     = 10
  validation {
    condition     = var.lambda_concurrent_executions >= 1
    error_message = "Lambda concurrent executions must be at least 1."
  }
}

variable "redis_endpoint" {
  description = "Redis endpoint for caching"
  type        = string
}

# Search Configuration
variable "indexing_batch_size" {
  description = "Batch size for search indexing operations"
  type        = number
  default     = 100
  validation {
    condition     = var.indexing_batch_size >= 1 && var.indexing_batch_size <= 1000
    error_message = "Indexing batch size must be between 1 and 1000."
  }
}

variable "max_indexing_retries" {
  description = "Maximum number of retries for failed indexing operations"
  type        = number
  default     = 3
  validation {
    condition     = var.max_indexing_retries >= 0 && var.max_indexing_retries <= 10
    error_message = "Max indexing retries must be between 0 and 10."
  }
}

variable "search_cache_ttl" {
  description = "Cache TTL for search results in seconds"
  type        = number
  default     = 300
  validation {
    condition     = var.search_cache_ttl >= 0
    error_message = "Search cache TTL must be non-negative."
  }
}

variable "max_search_results" {
  description = "Maximum number of search results to return"
  type        = number
  default     = 100
  validation {
    condition     = var.max_search_results >= 1 && var.max_search_results <= 1000
    error_message = "Max search results must be between 1 and 1000."
  }
}

variable "enable_search_analytics" {
  description = "Whether to enable search analytics"
  type        = bool
  default     = true
}

# Monitoring Configuration
variable "alarm_actions" {
  description = "List of ARNs for alarm actions (SNS topics, etc.)"
  type        = list(string)
  default     = []
}

# Tagging
variable "tags" {
  description = "Tags to apply to all resources"
  type        = map(string)
  default     = {}
}