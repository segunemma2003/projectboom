variable "name_prefix" {
  description = "Name prefix for resources"
  type        = string
}

variable "vpc_id" {
  description = "VPC ID"
  type        = string
}

variable "public_subnet_ids" {
  description = "Public subnet IDs for load balancers"
  type        = list(string)
}

variable "private_subnet_ids" {
  description = "Private subnet IDs for ECS tasks"
  type        = list(string)
}

variable "cluster_id" {
  description = "ECS cluster ID"
  type        = string
}

variable "cluster_name" {
  description = "ECS cluster name"
  type        = string
}

variable "execution_role_arn" {
  description = "ECS execution role ARN"
  type        = string
}

variable "task_role_arn" {
  description = "ECS task role ARN"
  type        = string
}

variable "certificate_arn" {
  description = "ACM certificate ARN"
  type        = string
}

variable "domain_name" {
  description = "Domain name for LiveKit"
  type        = string
}

variable "redis_endpoint" {
  description = "Redis cluster endpoint"
  type        = string
}

variable "redis_security_group_ids" {
  description = "Redis security group IDs"
  type        = list(string)
}

variable "aws_region" {
  description = "AWS region"
  type        = string
}

variable "livekit_image" {
  description = "LiveKit Docker image"
  type        = string
  default     = "livekit/livekit-server:latest"
}

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
  description = "LiveKit desired task count"
  type        = number
  default     = 6
}

variable "livekit_min_capacity" {
  description = "LiveKit minimum capacity"
  type        = number
  default     = 3
}

variable "livekit_max_capacity" {
  description = "LiveKit maximum capacity"
  type        = number
  default     = 20
}

variable "enable_recording" {
  description = "Enable LiveKit recording"
  type        = bool
  default     = true
}

variable "recordings_bucket_name" {
  description = "S3 bucket name for recordings"
  type        = string
}

variable "log_retention_days" {
  description = "CloudWatch log retention in days"
  type        = number
  default     = 14
}

variable "tags" {
  description = "Tags to apply to resources"
  type        = map(string)
  default     = {}
}