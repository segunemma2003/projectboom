variable "name_prefix" {
  description = "Name prefix for resources"
  type        = string
}

variable "alert_email" {
  description = "Email for alerts"
  type        = string
  default     = ""
}

variable "slack_webhook" {
  description = "Slack webhook URL"
  type        = string
  default     = ""
}

variable "tags" {
  description = "Tags to apply to resources"
  type        = map(string)
  default     = {}
}