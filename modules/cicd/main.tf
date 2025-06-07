terraform {
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
  }
}

# S3 bucket for CodePipeline artifacts
resource "aws_s3_bucket" "codepipeline_artifacts" {
  bucket = "${var.name_prefix}-codepipeline-artifacts-${random_id.bucket_suffix.hex}"
  
  tags = merge(var.tags, {
    Name = "${var.name_prefix}-codepipeline-artifacts"
  })
}

resource "random_id" "bucket_suffix" {
  byte_length = 4
}

resource "aws_s3_bucket_versioning" "codepipeline_artifacts" {
  bucket = aws_s3_bucket.codepipeline_artifacts.id
  versioning_configuration {
    status = "Enabled"
  }
}

resource "aws_s3_bucket_server_side_encryption_configuration" "codepipeline_artifacts" {
  bucket = aws_s3_bucket.codepipeline_artifacts.id

  rule {
    apply_server_side_encryption_by_default {
      sse_algorithm = "AES256"
    }
  }
}

resource "aws_s3_bucket_lifecycle_configuration" "codepipeline_artifacts" {
  bucket = aws_s3_bucket.codepipeline_artifacts.id

  rule {
    id     = "cleanup_artifacts"
    status = "Enabled"

    expiration {
      days = 30
    }

    noncurrent_version_expiration {
      noncurrent_days = 7
    }
  }
}

resource "aws_s3_bucket_public_access_block" "codepipeline_artifacts" {
  bucket = aws_s3_bucket.codepipeline_artifacts.id

  block_public_acls       = true
  block_public_policy     = true
  ignore_public_acls      = true
  restrict_public_buckets = true
}

# CodeBuild project for building containers
resource "aws_codebuild_project" "container_build" {
  for_each = toset(var.services)
  
  name          = "${var.name_prefix}-${each.value}-build"
  description   = "Build project for ${each.value} service"
  service_role  = aws_iam_role.codebuild.arn

  artifacts {
    type = "CODEPIPELINE"
  }

  environment {
    compute_type                = "BUILD_GENERAL1_MEDIUM"
    image                      = "aws/codebuild/amazonlinux2-x86_64-standard:5.0"
    type                       = "LINUX_CONTAINER"
    image_pull_credentials_type = "CODEBUILD"
    privileged_mode            = true

    environment_variable {
      name  = "AWS_DEFAULT_REGION"
      value = var.aws_region
    }

    environment_variable {
      name  = "AWS_ACCOUNT_ID"
      value = var.aws_account_id
    }

    environment_variable {
      name  = "IMAGE_REPO_NAME"
      value = "${var.name_prefix}/${each.value}"
    }

    environment_variable {
      name  = "IMAGE_TAG"
      value = "latest"
    }

    environment_variable {
      name  = "SERVICE_NAME"
      value = each.value
    }
  }

  source {
    type = "CODEPIPELINE"
    buildspec = "buildspecs/buildspec-${each.value}.yml"
  }

  cache {
    type  = "S3"
    location = "${aws_s3_bucket.codepipeline_artifacts.bucket}/cache/${each.value}"
  }

  logs_config {
    cloudwatch_logs {
      group_name  = aws_cloudwatch_log_group.codebuild.name
      stream_name = "${each.value}-build"
    }

    s3_logs {
      status   = "ENABLED"
      location = "${aws_s3_bucket.codepipeline_artifacts.bucket}/logs/${each.value}"
    }
  }

  tags = merge(var.tags, {
    Name    = "${var.name_prefix}-${each.value}-build"
    Service = each.value
  })
}

# CodeBuild project for security scanning
resource "aws_codebuild_project" "security_scan" {
  name         = "${var.name_prefix}-security-scan"
  description  = "Security scanning for infrastructure and containers"
  service_role = aws_iam_role.codebuild.arn

  artifacts {
    type = "CODEPIPELINE"
  }

  environment {
    compute_type                = "BUILD_GENERAL1_MEDIUM"
    image                      = "aws/codebuild/amazonlinux2-x86_64-standard:5.0"
    type                       = "LINUX_CONTAINER"
    image_pull_credentials_type = "CODEBUILD"

    environment_variable {
      name  = "CHECKOV_VERSION"
      value = "latest"
    }

    environment_variable {
      name  = "TRIVY_VERSION"
      value = "latest"
    }
  }

  source {
    type = "CODEPIPELINE"
    buildspec = templatefile("${path.module}/buildspecs/security-scan.yml", {
      project_name = var.name_prefix
    })
  }

  logs_config {
    cloudwatch_logs {
      group_name  = aws_cloudwatch_log_group.codebuild.name
      stream_name = "security-scan"
    }
  }

  tags = merge(var.tags, {
    Name = "${var.name_prefix}-security-scan"
    Type = "SecurityScan"
  })
}

# CodePipeline for infrastructure deployment
resource "aws_codepipeline" "infrastructure" {
  name     = "${var.name_prefix}-infrastructure-pipeline"
  role_arn = aws_iam_role.codepipeline.arn

  artifact_store {
    location = aws_s3_bucket.codepipeline_artifacts.bucket
    type     = "S3"

    encryption_key {
      id   = aws_kms_key.codepipeline.arn
      type = "KMS"
    }
  }

  stage {
    name = "Source"

    action {
      name             = "Source"
      category         = "Source"
      owner            = "AWS"
      provider         = "S3"
      version          = "1"
      output_artifacts = ["source_output"]

      configuration = {
        S3Bucket    = var.source_bucket
        S3ObjectKey = var.source_object_key
      }
    }
  }

  stage {
    name = "SecurityScan"

    action {
      name             = "SecurityScan"
      category         = "Build"
      owner            = "AWS"
      provider         = "CodeBuild"
      input_artifacts  = ["source_output"]
      output_artifacts = ["security_output"]
      version          = "1"

      configuration = {
        ProjectName = aws_codebuild_project.security_scan.name
      }
    }
  }

  stage {
    name = "Plan"

    action {
      name             = "TerraformPlan"
      category         = "Build"
      owner            = "AWS"
      provider         = "CodeBuild"
      input_artifacts  = ["source_output"]
      output_artifacts = ["plan_output"]
      version          = "1"

      configuration = {
        ProjectName = aws_codebuild_project.terraform_plan.name
      }
    }
  }

  stage {
    name = "Approval"

    action {
      name     = "ManualApproval"
      category = "Approval"
      owner    = "AWS"
      provider = "Manual"
      version  = "1"

      configuration = {
        NotificationArn = aws_sns_topic.pipeline_notifications.arn
        CustomData      = "Please review the Terraform plan and approve if acceptable."
      }
    }
  }

  stage {
    name = "Deploy"

    action {
      name             = "TerraformApply"
      category         = "Build"
      owner            = "AWS"
      provider         = "CodeBuild"
      input_artifacts  = ["plan_output"]
      version          = "1"

      configuration = {
        ProjectName = aws_codebuild_project.terraform_apply.name
      }
    }
  }

  tags = var.tags
}

# CodePipeline for application deployment
resource "aws_codepipeline" "application" {
  for_each = toset(var.services)
  
  name     = "${var.name_prefix}-${each.value}-pipeline"
  role_arn = aws_iam_role.codepipeline.arn

  artifact_store {
    location = aws_s3_bucket.codepipeline_artifacts.bucket
    type     = "S3"

    encryption_key {
      id   = aws_kms_key.codepipeline.arn
      type = "KMS"
    }
  }

  stage {
    name = "Source"

    action {
      name             = "Source"
      category         = "Source"
      owner            = "ThirdParty"
      provider         = "GitHub"
      version          = "1"
      output_artifacts = ["source_output"]

      configuration = {
        Owner  = var.github_owner
        Repo   = "${var.name_prefix}-${each.value}"
        Branch = var.github_branch
        OAuthToken = var.github_token
      }
    }
  }

  stage {
    name = "Build"

    action {
      name             = "Build"
      category         = "Build"
      owner            = "AWS"
      provider         = "CodeBuild"
      input_artifacts  = ["source_output"]
      output_artifacts = ["build_output"]
      version          = "1"

      configuration = {
        ProjectName = aws_codebuild_project.container_build[each.key].name
      }
    }
  }

  stage {
    name = "Deploy"

    action {
      name             = "Deploy"
      category         = "Deploy"
      owner            = "AWS"
      provider         = "ECS"
      input_artifacts  = ["build_output"]
      version          = "1"

      configuration = {
        ClusterName = var.ecs_cluster_name
        ServiceName = "${var.name_prefix}-${each.value}"
        FileName    = "imagedefinitions.json"
      }
    }
  }

  tags = merge(var.tags, {
    Name    = "${var.name_prefix}-${each.value}-pipeline"
    Service = each.value
  })
}

# CodeBuild projects for Terraform operations
resource "aws_codebuild_project" "terraform_plan" {
  name         = "${var.name_prefix}-terraform-plan"
  description  = "Terraform plan for infrastructure changes"
  service_role = aws_iam_role.codebuild.arn

  artifacts {
    type = "CODEPIPELINE"
  }

  environment {
    compute_type                = "BUILD_GENERAL1_MEDIUM"
    image                      = "aws/codebuild/amazonlinux2-x86_64-standard:5.0"
    type                       = "LINUX_CONTAINER"
    image_pull_credentials_type = "CODEBUILD"

    environment_variable {
      name  = "TF_VERSION"
      value = var.terraform_version
    }

    environment_variable {
      name  = "ENVIRONMENT"
      value = var.environment
    }
  }

  source {
    type = "CODEPIPELINE"
    buildspec = file("${path.module}/buildspecs/terraform-plan.yml")
  }

  logs_config {
    cloudwatch_logs {
      group_name  = aws_cloudwatch_log_group.codebuild.name
      stream_name = "terraform-plan"
    }
  }

  tags = merge(var.tags, {
    Name = "${var.name_prefix}-terraform-plan"
    Type = "TerraformPlan"
  })
}

resource "aws_codebuild_project" "terraform_apply" {
  name         = "${var.name_prefix}-terraform-apply"
  description  = "Terraform apply for infrastructure changes"
  service_role = aws_iam_role.codebuild.arn

  artifacts {
    type = "CODEPIPELINE"
  }

  environment {
    compute_type                = "BUILD_GENERAL1_MEDIUM"
    image                      = "aws/codebuild/amazonlinux2-x86_64-standard:5.0"
    type                       = "LINUX_CONTAINER"
    image_pull_credentials_type = "CODEBUILD"

    environment_variable {
      name  = "TF_VERSION"
      value = var.terraform_version
    }

    environment_variable {
      name  = "ENVIRONMENT"
      value = var.environment
    }
  }

  source {
    type = "CODEPIPELINE"
    buildspec = file("${path.module}/buildspecs/terraform-apply.yml")
  }

  logs_config {
    cloudwatch_logs {
      group_name  = aws_cloudwatch_log_group.codebuild.name
      stream_name = "terraform-apply"
    }
  }

  tags = merge(var.tags, {
    Name = "${var.name_prefix}-terraform-apply"
    Type = "TerraformApply"
  })
}

# CloudWatch Log Group for CodeBuild
resource "aws_cloudwatch_log_group" "codebuild" {
  name              = "/aws/codebuild/${var.name_prefix}"
  retention_in_days = var.log_retention_days

  tags = merge(var.tags, {
    Name = "${var.name_prefix}-codebuild-logs"
  })
}

# SNS topic for pipeline notifications
resource "aws_sns_topic" "pipeline_notifications" {
  name = "${var.name_prefix}-pipeline-notifications"

  tags = var.tags
}

resource "aws_sns_topic_subscription" "pipeline_email" {
  count     = length(var.notification_emails)
  topic_arn = aws_sns_topic.pipeline_notifications.arn
  protocol  = "email"
  endpoint  = var.notification_emails[count.index]
}

# KMS key for CodePipeline encryption
resource "aws_kms_key" "codepipeline" {
  description             = "KMS key for CodePipeline encryption"
  deletion_window_in_days = 7

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Sid    = "Enable IAM User Permissions"
        Effect = "Allow"
        Principal = {
          AWS = "arn:aws:iam::${var.aws_account_id}:root"
        }
        Action   = "kms:*"
        Resource = "*"
      },
      {
        Sid    = "Allow CodePipeline Service"
        Effect = "Allow"
        Principal = {
          Service = [
            "codepipeline.amazonaws.com",
            "codebuild.amazonaws.com"
          ]
        }
        Action = [
          "kms:Decrypt",
          "kms:GenerateDataKey"
        ]
        Resource = "*"
      }
    ]
  })

  tags = merge(var.tags, {
    Name = "${var.name_prefix}-codepipeline-kms"
  })
}

resource "aws_kms_alias" "codepipeline" {
  name          = "alias/${var.name_prefix}-codepipeline"
  target_key_id = aws_kms_key.codepipeline.key_id
}