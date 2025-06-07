variable "name_prefix" {
  description = "Name prefix for resources"
  type        = string
}

variable "cluster_name" {
  description = "ECS cluster name"
  type        = string
}

variable "service_names" {
  description = "Map of service names"
  type        = map(string)
}

variable "min_capacity" {
  description = "Minimum capacity"
  type        = number
  default     = 1
}

variable "max_capacity" {
  description = "Maximum capacity"
  type        = number
  default     = 10
}

variable "tags" {
  description = "Tags to apply to resources"
  type        = map(string)
  default     = {}
}
