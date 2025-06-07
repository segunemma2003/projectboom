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

# Image processing configuration
variable "max_image_size" {
  description = "Maximum image size in bytes"
  type        = number
  default     = 10485760  # 10MB
}

variable "allowed_image_formats" {
  description = "List of allowed image formats"
  type        = list(string)
  default     = ["jpg", "jpeg", "png", "gif", "webp"]
}

variable "thumbnail_sizes" {
  description = "List of thumbnail sizes to generate"
  type        = list(object({
    width  = number
    height = number
    name   = string
  }))
  default = [
    {
      width  = 150
      height = 150
      name   = "small"
    },
    {
      width  = 300
      height = 300
      name   = "medium"
    },
    {
      width  = 600
      height = 600
      name   = "large"
    }
  ]
}

# Video processing configuration
variable "max_video_size" {
  description = "Maximum video size in bytes"
  type        = number
  default     = 104857600  # 100MB
}

variable "allowed_video_formats" {
  description = "List of allowed video input formats"
  type        = list(string)
  default     = ["mp4", "mov", "avi", "mkv", "webm"]
}

variable "video_output_formats" {
  description = "List of video output formats and qualities"
  type        = list(object({
    format    = string
    quality   = string
    bitrate   = string
    width     = number
    height    = number
  }))
  default = [
    {
      format    = "mp4"
      quality   = "720p"
      bitrate   = "2000k"
      width     = 1280
      height    = 720
    },
    {
      format    = "mp4"
      quality   = "480p"
      bitrate   = "1000k"
      width     = 854
      height    = 480
    },
    {
      format    = "webm"
      quality   = "720p"
      bitrate   = "1500k"
      width     = 1280
      height    = 720
    }
  ]
}

# MediaConvert configuration
variable "mediaconvert_pricing_plan" {
  description = "MediaConvert pricing plan"
  type        = string
  default     = "ON_DEMAND"
  
  validation {
    condition     = contains(["ON_DEMAND", "RESERVED"], var.mediaconvert_pricing_plan)
    error_message = "MediaConvert pricing plan must be either ON_DEMAND or RESERVED."
  }
}

variable "mediaconvert_commitment" {
  description = "MediaConvert commitment for reserved pricing"
  type        = string
  default     = "ONE_YEAR"
  
  validation {
    condition     = contains(["ONE_YEAR", "THREE_YEAR"], var.mediaconvert_commitment)
    error_message = "MediaConvert commitment must be either ONE_YEAR or THREE_YEAR."
  }
}

variable "mediaconvert_reserved_slots" {
  description = "Number of reserved slots for MediaConvert"
  type        = number
  default     = 0
}

# Lambda configuration
variable "lambda_concurrent_executions" {
  description = "Reserved concurrent executions for Lambda functions"
  type        = number
  default     = 25
}

variable "lambda_timeout" {
  description = "Lambda function timeout in seconds"
  type        = number
  default     = 300
}

variable "lambda_memory_size" {
  description = "Lambda function memory size in MB"
  type        = number
  default     = 1024
}

# Storage configuration
variable "raw_media_retention_days" {
  description = "Number of days to retain raw media files"
  type        = number
  default     = 7
}

variable "enable_versioning" {
  description = "Enable S3 bucket versioning"
  type        = bool
  default     = true
}

variable "enable_cross_region_replication" {
  description = "Enable cross-region replication for media buckets"
  type        = bool
  default     = false
}

variable "replication_region" {
  description = "Target region for cross-region replication"
  type        = string
  default     = "us-east-1"
}

# Content moderation
variable "enable_content_moderation" {
  description = "Enable automatic content moderation using AWS Rekognition"
  type        = bool
  default     = true
}

variable "rekognition_min_confidence" {
  description = "Minimum confidence threshold for Rekognition moderation"
  type        = number
  default     = 80
}

variable "moderation_labels_to_block" {
  description = "List of Rekognition moderation labels that should block content"
  type        = list(string)
  default     = [
    "Explicit Nudity",
    "Graphic Violence",
    "Hate Symbols",
    "Drugs",
    "Tobacco",
    "Alcohol"
  ]
}

# API Gateway configuration
variable "enable_direct_upload_api" {
  description = "Enable API Gateway for direct file uploads"
  type        = bool
  default     = true
}

variable "max_upload_size" {
  description = "Maximum upload size via API Gateway in bytes"
  type        = number
  default     = 10485760  # 10MB
}

variable "upload_expiration_minutes" {
  description = "Presigned URL expiration time in minutes"
  type        = number
  default     = 15
}

# Monitoring and alerting
variable "alarm_actions" {
  description = "SNS topic ARNs for alarm actions"
  type        = list(string)
  default     = []
}

variable "error_threshold" {
  description = "Error threshold for CloudWatch alarms"
  type        = number
  default     = 5
}

variable "processing_queue_depth_threshold" {
  description = "Queue depth threshold for processing alarms"
  type        = number
  default     = 100
}

variable "enable_detailed_monitoring" {
  description = "Enable detailed CloudWatch monitoring"
  type        = bool
  default     = true
}

# Cost optimization
variable "enable_intelligent_tiering" {
  description = "Enable S3 Intelligent Tiering for cost optimization"
  type        = bool
  default     = true
}

variable "transition_to_ia_days" {
  description = "Days after which to transition to Infrequent Access storage"
  type        = number
  default     = 30
}

variable "transition_to_glacier_days" {
  description = "Days after which to transition to Glacier storage"
  type        = number
  default     = 90
}

variable "transition_to_deep_archive_days" {
  description = "Days after which to transition to Deep Archive storage"
  type        = number
  default     = 365
}

# Processing optimization
variable "processing_batch_size" {
  description = "Batch size for media processing jobs"
  type        = number
  default     = 10
}

variable "enable_parallel_processing" {
  description = "Enable parallel processing for multiple formats"
  type        = bool
  default     = true
}

variable "max_concurrent_jobs" {
  description = "Maximum concurrent MediaConvert jobs"
  type        = number
  default     = 20
}

# Quality settings
variable "image_quality" {
  description = "JPEG quality setting (1-100)"
  type        = number
  default     = 85
  
  validation {
    condition     = var.image_quality >= 1 && var.image_quality <= 100
    error_message = "Image quality must be between 1 and 100."
  }
}

variable "video_preset" {
  description = "Default video encoding preset"
  type        = string
  default     = "System-Generic_Hd_Mp4_Avc_Aac_16x9_1920x1080p_24Hz_6Mbps"
}

# Security
variable "enable_encryption" {
  description = "Enable server-side encryption for S3 buckets"
  type        = bool
  default     = true
}

variable "kms_key_id" {
  description = "KMS key ID for encryption (leave empty for AWS managed keys)"
  type        = string
  default     = ""
}

# Tags
variable "tags" {
  description = "Tags to apply to resources"
  type        = map(string)
  default     = {}
}