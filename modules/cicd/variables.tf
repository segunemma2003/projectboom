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

variable "aws_region" {
  description = "AWS region for resources"
  type        = string
}

variable "aws_account_id" {
  description = "AWS account ID"
  type        = string
  validation {
    condition     = can(regex("^[0-9]{12}$", var.aws_account_id))
    error_message = "AWS account ID must be a 12-digit number."
  }
}

# Service Configuration
variable "services" {
  description = "List of services to create pipelines for"
  type        = list(string)
  validation {
    condition     = length(var.services) > 0
    error_message = "At least one service must be specified."
  }
}

variable "ecs_cluster_name" {
  description = "Name of the ECS cluster for deployments"
  type        = string
}

# Source Configuration
variable "source_bucket" {
  description = "S3 bucket for infrastructure source code"
  type        = string
}

variable "source_object_key" {
  description = "S3 object key for infrastructure source code"
  type        = string
  default     = "infrastructure.zip"
}

# GitHub Configuration
variable "github_owner" {
  description = "GitHub repository owner/organization"
  type        = string
}

variable "github_branch" {
  description = "GitHub branch to use for source"
  type        = string
  default     = "main"
}

variable "github_token" {
  description = "GitHub personal access token for CodePipeline"
  type        = string
  sensitive   = true
}

# Build Configuration
variable "terraform_version" {
  description = "Terraform version to use in CodeBuild"
  type        = string
  default     = "1.6.0"
  validation {
    condition     = can(regex("^[0-9]+\\.[0-9]+\\.[0-9]+$", var.terraform_version))
    error_message = "Terraform version must be in semantic version format (e.g., 1.6.0)."
  }
}

variable "codebuild_compute_type" {
  description = "CodeBuild compute type"
  type        = string
  default     = "BUILD_GENERAL1_MEDIUM"
  validation {
    condition = contains([
      "BUILD_GENERAL1_SMALL",
      "BUILD_GENERAL1_MEDIUM",
      "BUILD_GENERAL1_LARGE",
      "BUILD_GENERAL1_XLARGE",
      "BUILD_GENERAL1_2XLARGE"
    ], var.codebuild_compute_type)
    error_message = "CodeBuild compute type must be a valid AWS CodeBuild compute type."
  }
}

variable "codebuild_image" {
  description = "Docker image to use for CodeBuild projects"
  type        = string
  default     = "aws/codebuild/amazonlinux2-x86_64-standard:5.0"
}

variable "enable_build_cache" {
  description = "Whether to enable S3 cache for CodeBuild projects"
  type        = bool
  default     = true
}

variable "enable_build_badges" {
  description = "Whether to enable build badges for CodeBuild projects"
  type        = bool
  default     = false
}

# Security Configuration
variable "enable_security_scanning" {
  description = "Whether to enable security scanning in the pipeline"
  type        = bool
  default     = true
}

variable "checkov_version" {
  description = "Version of Checkov to use for security scanning"
  type        = string
  default     = "latest"
}

variable "trivy_version" {
  description = "Version of Trivy to use for container scanning"
  type        = string
  default     = "latest"
}

variable "security_scan_timeout" {
  description = "Timeout in minutes for security scanning"
  type        = number
  default     = 30
  validation {
    condition     = var.security_scan_timeout >= 5 && var.security_scan_timeout <= 480
    error_message = "Security scan timeout must be between 5 and 480 minutes."
  }
}

# Pipeline Configuration
variable "enable_manual_approval" {
  description = "Whether to enable manual approval step in infrastructure pipeline"
  type        = bool
  default     = true
}

variable "pipeline_timeout" {
  description = "Timeout in minutes for pipeline execution"
  type        = number
  default     = 60
  validation {
    condition     = var.pipeline_timeout >= 5 && var.pipeline_timeout <= 480
    error_message = "Pipeline timeout must be between 5 and 480 minutes."
  }
}

variable "artifact_retention_days" {
  description = "Number of days to retain pipeline artifacts"
  type        = number
  default     = 30
  validation {
    condition     = var.artifact_retention_days >= 1 && var.artifact_retention_days <= 3653
    error_message = "Artifact retention days must be between 1 and 3653."
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

variable "enable_s3_logging" {
  description = "Whether to enable S3 logging for CodeBuild projects"
  type        = bool
  default     = true
}

variable "enable_cloudwatch_logging" {
  description = "Whether to enable CloudWatch logging for CodeBuild projects"
  type        = bool
  default     = true
}

# Notification Configuration
variable "notification_emails" {
  description = "List of email addresses to receive pipeline notifications"
  type        = list(string)
  default     = []
  validation {
    condition = alltrue([
      for email in var.notification_emails : can(regex("^[a-zA-Z0-9._%+-]+@[a-zA-Z0-9.-]+\\.[a-zA-Z]{2,}$", email))
    ])
    error_message = "All notification emails must be valid email addresses."
  }
}

variable "enable_slack_notifications" {
  description = "Whether to enable Slack notifications"
  type        = bool
  default     = false
}

variable "slack_webhook_url" {
  description = "Slack webhook URL for notifications"
  type        = string
  default     = ""
  sensitive   = true
}

variable "slack_channel" {
  description = "Slack channel for notifications"
  type        = string
  default     = "#deployments"
}

# KMS Configuration
variable "kms_key_deletion_window" {
  description = "KMS key deletion window in days"
  type        = number
  default     = 7
  validation {
    condition     = var.kms_key_deletion_window >= 7 && var.kms_key_deletion_window <= 30
    error_message = "KMS key deletion window must be between 7 and 30 days."
  }
}

variable "enable_kms_key_rotation" {
  description = "Whether to enable automatic KMS key rotation"
  type        = bool
  default     = true
}

# Custom Buildspec Configuration
variable "custom_buildspecs" {
  description = "Map of service names to custom buildspec file paths"
  type        = map(string)
  default     = {}
}

variable "buildspec_directory" {
  description = "Directory containing buildspec files relative to module path"
  type        = string
  default     = "buildspecs"
}

# Environment Variables
variable "global_environment_variables" {
  description = "Global environment variables to add to all CodeBuild projects"
  type = map(object({
    value = string
    type  = optional(string, "PLAINTEXT")
  }))
  default = {}
}

variable "service_environment_variables" {
  description = "Service-specific environment variables for CodeBuild projects"
  type = map(map(object({
    value = string
    type  = optional(string, "PLAINTEXT")
  })))
  default = {}
}

# VPC Configuration (Optional)
variable "vpc_config" {
  description = "VPC configuration for CodeBuild projects"
  type = object({
    vpc_id             = string
    subnets            = list(string)
    security_group_ids = list(string)
  })
  default = null
}

# IAM Configuration
variable "additional_iam_policies" {
  description = "List of additional IAM policy ARNs to attach to CodeBuild role"
  type        = list(string)
  default     = []
}

variable "custom_codebuild_policy" {
  description = "Custom IAM policy document for CodeBuild role"
  type        = string
  default     = ""
}

variable "custom_codepipeline_policy" {
  description = "Custom IAM policy document for CodePipeline role"
  type        = string
  default     = ""
}

# Deployment Configuration
variable "deployment_configuration" {
  description = "ECS deployment configuration settings"
  type = object({
    minimum_healthy_percent         = optional(number, 50)
    maximum_percent                = optional(number, 200)
    deployment_circuit_breaker = optional(object({
      enable   = bool
      rollback = bool
    }), {
      enable   = true
      rollback = true
    })
  })
  default = {}
}

# Monitoring and Alerting
variable "enable_pipeline_metrics" {
  description = "Whether to enable detailed pipeline metrics"
  type        = bool
  default     = true
}

variable "failure_notification_threshold" {
  description = "Number of consecutive failures before sending notification"
  type        = number
  default     = 1
  validation {
    condition     = var.failure_notification_threshold >= 1 && var.failure_notification_threshold <= 10
    error_message = "Failure notification threshold must be between 1 and 10."
  }
}

# Cost Optimization
variable "enable_spot_fleet" {
  description = "Whether to use Spot Fleet for CodeBuild projects"
  type        = bool
  default     = false
}

variable "build_timeout_minutes" {
  description = "Build timeout in minutes"
  type        = number
  default     = 60
  validation {
    condition     = var.build_timeout_minutes >= 5 && var.build_timeout_minutes <= 480
    error_message = "Build timeout must be between 5 and 480 minutes."
  }
}

# Feature Flags
variable "enable_cross_region_replication" {
  description = "Whether to enable cross-region replication for artifacts"
  type        = bool
  default     = false
}

variable "enable_parallel_builds" {
  description = "Whether to enable parallel builds for multiple services"
  type        = bool
  default     = true
}

variable "enable_test_stage" {
  description = "Whether to include a testing stage in the pipeline"
  type        = bool
  default     = true
}

variable "enable_rollback_capability" {
  description = "Whether to enable automatic rollback capability"
  type        = bool
  default     = true
}

# Tagging
variable "tags" {
  description = "Tags to apply to all resources"
  type        = map(string)
  default     = {}
}