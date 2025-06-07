# bootstrap/main.tf - Create this file to bootstrap your backend
terraform {
  required_version = ">= 1.0"
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
    random = {
      source  = "hashicorp/random"
      version = "~> 3.1"
    }
  }
}

provider "aws" {
  region = var.aws_region
  
  default_tags {
    tags = {
      Project   = var.project_name
      ManagedBy = "terraform"
      Purpose   = "backend-infrastructure"
    }
  }
}

# Get current AWS account ID and region
data "aws_caller_identity" "current" {}
data "aws_region" "current" {}

# Generate random suffix for globally unique bucket names
resource "random_id" "bucket_suffix" {
  byte_length = 4
}

locals {
  account_id = data.aws_caller_identity.current.account_id
  region     = data.aws_region.current.name
  
  # Create unique bucket names
  buckets = {
    dev     = "${var.project_name}-terraform-state-dev-${local.account_id}-${random_id.bucket_suffix.hex}"
    staging = "${var.project_name}-terraform-state-staging-${local.account_id}-${random_id.bucket_suffix.hex}"
    prod    = "${var.project_name}-terraform-state-prod-${local.account_id}-${random_id.bucket_suffix.hex}"
  }
  
  # DynamoDB table names
  dynamodb_tables = {
    dev     = "terraform-state-locks-dev"
    staging = "terraform-state-locks-staging"
    prod    = "terraform-state-locks-prod"
  }
}

# S3 buckets for Terraform state
resource "aws_s3_bucket" "terraform_state" {
  for_each = local.buckets
  
  bucket        = each.value
  force_destroy = false # Protect against accidental deletion
  
  tags = {
    Name        = each.value
    Environment = each.key
  }
}

# Enable versioning for state buckets
resource "aws_s3_bucket_versioning" "terraform_state" {
  for_each = aws_s3_bucket.terraform_state
  
  bucket = each.value.id
  versioning_configuration {
    status = "Enabled"
  }
}

# Enable server-side encryption
resource "aws_s3_bucket_server_side_encryption_configuration" "terraform_state" {
  for_each = aws_s3_bucket.terraform_state
  
  bucket = each.value.id

  rule {
    apply_server_side_encryption_by_default {
      sse_algorithm = "AES256"
    }
    bucket_key_enabled = true
  }
}

# Block public access
resource "aws_s3_bucket_public_access_block" "terraform_state" {
  for_each = aws_s3_bucket.terraform_state
  
  bucket = each.value.id

  block_public_acls       = true
  block_public_policy     = true
  ignore_public_acls      = true
  restrict_public_buckets = true
}

# Lifecycle configuration to manage old versions
resource "aws_s3_bucket_lifecycle_configuration" "terraform_state" {
  for_each = aws_s3_bucket.terraform_state
  
  bucket = each.value.id

  rule {
    id     = "terraform_state_lifecycle"
    status = "Enabled"

    noncurrent_version_expiration {
      noncurrent_days = 90
    }

    abort_incomplete_multipart_upload {
      days_after_initiation = 7
    }
  }
}

# DynamoDB tables for state locking
resource "aws_dynamodb_table" "terraform_locks" {
  for_each = local.dynamodb_tables
  
  name           = each.value
  billing_mode   = "PAY_PER_REQUEST"
  hash_key       = "LockID"

  attribute {
    name = "LockID"
    type = "S"
  }

  tags = {
    Name        = each.value
    Environment = each.key
  }
}

# Generate backend configuration files
resource "local_file" "backend_configs" {
  for_each = local.buckets
  
  filename = "../environments/${each.key}/backend.tf"
  content = templatefile("${path.module}/backend.tftpl", {
    bucket         = each.value
    key            = "${each.key}/terraform.tfstate"
    region         = local.region
    dynamodb_table = local.dynamodb_tables[each.key]
  })
}

# Output information needed to update backend configs
output "backend_info" {
  description = "Backend configuration information"
  value = {
    account_id = local.account_id
    region     = local.region
    buckets    = local.buckets
    tables     = local.dynamodb_tables
  }
}

output "next_steps" {
  description = "Next steps to complete setup"
  value = <<-EOT
    Backend infrastructure created successfully!
    
    Next steps:
    1. Copy the generated backend.tf files to your environment directories
    2. Run 'terraform init' in each environment directory
    3. Your state will now be stored remotely in S3
    
    Buckets created:
    %{for k, v in local.buckets~}
    - ${k}: ${v}
    %{endfor~}
    
    DynamoDB tables created:
    %{for k, v in local.dynamodb_tables~}
    - ${k}: ${v}
    %{endfor~}
  EOT
}