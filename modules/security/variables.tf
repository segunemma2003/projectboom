variable "name_prefix" {
  description = "Name prefix for resources"
  type        = string
}

variable "vpc_id" {
  description = "VPC ID"
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

variable "tags" {
  description = "Tags to apply to resources"
  type        = map(string)
  default     = {}
}
