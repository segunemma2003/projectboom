variable "name_prefix" {
  description = "Name prefix for resources"
  type        = string
}

variable "s3_bucket_arns" {
  description = "S3 bucket ARNs for access"
  type        = list(string)
  default     = []
}

variable "tags" {
  description = "Tags to apply to resources"
  type        = map(string)
  default     = {}
}
