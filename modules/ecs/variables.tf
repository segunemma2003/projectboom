variable "name_prefix" {
  description = "Name prefix for resources"
  type        = string
}

variable "cluster_name" {
  description = "ECS cluster name"
  type        = string
}

variable "environment" {
  description = "Environment name (development, staging, production)"
  type        = string
}

variable "services" {
  description = "Map of services to create"
  type = map(object({
    image            = string
    cpu              = number
    memory           = number
    port             = number
    desired_count    = number
    environment      = list(object({
      name  = string
      value = string
    }))
    secrets          = list(object({
      name      = string
      valueFrom = string
    }))
    health_check     = list(string)
    target_group_arn = string
  }))
}

variable "execution_role_arn" {
  description = "ECS execution role ARN"
  type        = string
}

variable "task_role_arn" {
  description = "ECS task role ARN"
  type        = string
}

variable "security_group_ids" {
  description = "Security group IDs"
  type        = list(string)
}

variable "subnet_ids" {
  description = "Subnet IDs"
  type        = list(string)
}

variable "log_group_name" {
  description = "CloudWatch log group name"
  type        = string
}

variable "aws_region" {
  description = "AWS region"
  type        = string
}

variable "target_group_arns" {
  description = "Target group ARNs for dependency"
  type        = list(string)
  default     = []
}

variable "fargate_base" {
  description = "Fargate base capacity"
  type        = number
  default     = 1
}

variable "fargate_weight" {
  description = "Fargate weight"
  type        = number
  default     = 80
}

variable "fargate_spot_base" {
  description = "Fargate Spot base capacity"
  type        = number
  default     = 0
}

variable "fargate_spot_weight" {
  description = "Fargate Spot weight"
  type        = number
  default     = 20
}

variable "tags" {
  description = "Tags to apply to resources"
  type        = map(string)
  default     = {}
}