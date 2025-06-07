variable "project_name" {
  description = "Name of the project"
  type        = string
  default     = "social-platform"
}

variable "aws_region" {
  description = "AWS region"
  type        = string
  default     = "eu-west-1"
}

# bootstrap/backend.tftpl
terraform {
  backend "s3" {
    bucket         = "${bucket}"
    key            = "${key}"
    region         = "${region}"
    encrypt        = true
    dynamodb_table = "${dynamodb_table}"
  }
}