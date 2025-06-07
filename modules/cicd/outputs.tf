# S3 Bucket Outputs
output "artifacts_bucket_name" {
  description = "Name of the S3 bucket for CodePipeline artifacts"
  value       = aws_s3_bucket.codepipeline_artifacts.bucket
}

output "artifacts_bucket_arn" {
  description = "ARN of the S3 bucket for CodePipeline artifacts"
  value       = aws_s3_bucket.codepipeline_artifacts.arn
}

output "artifacts_bucket_domain_name" {
  description = "Domain name of the S3 bucket for CodePipeline artifacts"
  value       = aws_s3_bucket.codepipeline_artifacts.bucket_domain_name
}

output "artifacts_bucket_regional_domain_name" {
  description = "Regional domain name of the S3 bucket for CodePipeline artifacts"
  value       = aws_s3_bucket.codepipeline_artifacts.bucket_regional_domain_name
}

# CodeBuild Project Outputs
output "container_build_projects" {
  description = "Map of service names to CodeBuild project details for container builds"
  value = {
    for service, project in aws_codebuild_project.container_build : service => {
      name        = project.name
      arn         = project.arn
      service_role = project.service_role
    }
  }
}

output "container_build_project_names" {
  description = "List of CodeBuild project names for container builds"
  value       = [for project in aws_codebuild_project.container_build : project.name]
}

output "container_build_project_arns" {
  description = "List of CodeBuild project ARNs for container builds"
  value       = [for project in aws_codebuild_project.container_build : project.arn]
}

output "security_scan_project_name" {
  description = "Name of the security scan CodeBuild project"
  value       = aws_codebuild_project.security_scan.name
}

output "security_scan_project_arn" {
  description = "ARN of the security scan CodeBuild project"
  value       = aws_codebuild_project.security_scan.arn
}

output "terraform_plan_project_name" {
  description = "Name of the Terraform plan CodeBuild project"
  value       = aws_codebuild_project.terraform_plan.name
}

output "terraform_plan_project_arn" {
  description = "ARN of the Terraform plan CodeBuild project"
  value       = aws_codebuild_project.terraform_plan.arn
}

output "terraform_apply_project_name" {
  description = "Name of the Terraform apply CodeBuild project"
  value       = aws_codebuild_project.terraform_apply.name
}

output "terraform_apply_project_arn" {
  description = "ARN of the Terraform apply CodeBuild project"
  value       = aws_codebuild_project.terraform_apply.arn
}

# CodePipeline Outputs
output "infrastructure_pipeline_name" {
  description = "Name of the infrastructure CodePipeline"
  value       = aws_codepipeline.infrastructure.name
}

output "infrastructure_pipeline_arn" {
  description = "ARN of the infrastructure CodePipeline"
  value       = aws_codepipeline.infrastructure.arn
}

output "application_pipelines" {
  description = "Map of service names to application pipeline details"
  value = {
    for service, pipeline in aws_codepipeline.application : service => {
      name = pipeline.name
      arn  = pipeline.arn
    }
  }
}

output "application_pipeline_names" {
  description = "List of application pipeline names"
  value       = [for pipeline in aws_codepipeline.application : pipeline.name]
}

output "application_pipeline_arns" {
  description = "List of application pipeline ARNs"
  value       = [for pipeline in aws_codepipeline.application : pipeline.arn]
}

# IAM Role Outputs
output "codebuild_role_arn" {
  description = "ARN of the CodeBuild IAM role"
  value       = aws_iam_role.codebuild.arn
}

output "codebuild_role_name" {
  description = "Name of the CodeBuild IAM role"
  value       = aws_iam_role.codebuild.name
}

output "codepipeline_role_arn" {
  description = "ARN of the CodePipeline IAM role"
  value       = aws_iam_role.codepipeline.arn
}

output "codepipeline_role_name" {
  description = "Name of the CodePipeline IAM role"
  value       = aws_iam_role.codepipeline.name
}

# KMS Key Outputs
output "kms_key_id" {
  description = "ID of the KMS key used for CodePipeline encryption"
  value       = aws_kms_key.codepipeline.key_id
}

output "kms_key_arn" {
  description = "ARN of the KMS key used for CodePipeline encryption"
  value       = aws_kms_key.codepipeline.arn
}

output "kms_key_alias" {
  description = "Alias of the KMS key used for CodePipeline encryption"
  value       = aws_kms_alias.codepipeline.name
}

output "kms_key_alias_arn" {
  description = "ARN of the KMS key alias used for CodePipeline encryption"
  value       = aws_kms_alias.codepipeline.arn
}

# SNS Topic Outputs
output "pipeline_notifications_topic_arn" {
  description = "ARN of the SNS topic for pipeline notifications"
  value       = aws_sns_topic.pipeline_notifications.arn
}

output "pipeline_notifications_topic_name" {
  description = "Name of the SNS topic for pipeline notifications"
  value       = aws_sns_topic.pipeline_notifications.name
}

output "pipeline_notification_subscriptions" {
  description = "List of SNS topic subscription ARNs for pipeline notifications"
  value       = [for sub in aws_sns_topic_subscription.pipeline_email : sub.arn]
}

# CloudWatch Logs Outputs
output "codebuild_log_group_name" {
  description = "Name of the CloudWatch log group for CodeBuild projects"
  value       = aws_cloudwatch_log_group.codebuild.name
}

output "codebuild_log_group_arn" {
  description = "ARN of the CloudWatch log group for CodeBuild projects"
  value       = aws_cloudwatch_log_group.codebuild.arn
}

# Configuration Outputs
output "pipeline_configuration" {
  description = "Summary of pipeline configuration"
  value = {
    infrastructure_pipeline = {
      name = aws_codepipeline.infrastructure.name
      arn  = aws_codepipeline.infrastructure.arn
    }
    application_pipelines = {
      for service, pipeline in aws_codepipeline.application : service => {
        name = pipeline.name
        arn  = pipeline.arn
      }
    }
    artifacts_bucket = aws_s3_bucket.codepipeline_artifacts.bucket
    kms_key_arn     = aws_kms_key.codepipeline.arn
    sns_topic_arn   = aws_sns_topic.pipeline_notifications.arn
  }
}

output "build_configuration" {
  description = "Summary of build configuration"
  value = {
    container_builds = {
      for service, project in aws_codebuild_project.container_build : service => {
        name = project.name
        arn  = project.arn
      }
    }
    security_scan = {
      name = aws_codebuild_project.security_scan.name
      arn  = aws_codebuild_project.security_scan.arn
    }
    terraform_plan = {
      name = aws_codebuild_project.terraform_plan.name
      arn  = aws_codebuild_project.terraform_plan.arn
    }
    terraform_apply = {
      name = aws_codebuild_project.terraform_apply.name
      arn  = aws_codebuild_project.terraform_apply.arn
    }
  }
}

# Service-specific Outputs
output "service_build_projects" {
  description = "Map of services to their build project details"
  value = {
    for service in var.services : service => {
      build_project_name = aws_codebuild_project.container_build[service].name
      build_project_arn  = aws_codebuild_project.container_build[service].arn
      pipeline_name      = aws_codepipeline.application[service].name
      pipeline_arn       = aws_codepipeline.application[service].arn
      image_repo_name    = "${var.name_prefix}/${service}"
    }
  }
}

# External Integration Outputs
output "webhook_urls" {
  description = "Webhook URLs for external integration"
  value = {
    for service, pipeline in aws_codepipeline.application : service => 
    "https://webhooks.${var.aws_region}.amazonaws.com/trigger/codepipeline/${pipeline.name}"
  }
  sensitive = false
}

output "github_webhook_configuration" {
  description = "Configuration details for GitHub webhooks"
  value = {
    for service in var.services : service => {
      repository_name = "${var.name_prefix}-${service}"
      branch         = var.github_branch
      events         = ["push", "pull_request"]
    }
  }
}

# Resource Identifiers
output "resource_identifiers" {
  description = "Resource identifiers for external references"
  value = {
    artifacts_bucket_name           = aws_s3_bucket.codepipeline_artifacts.bucket
    infrastructure_pipeline_name    = aws_codepipeline.infrastructure.name
    security_scan_project_name      = aws_codebuild_project.security_scan.name
    terraform_plan_project_name     = aws_codebuild_project.terraform_plan.name
    terraform_apply_project_name    = aws_codebuild_project.terraform_apply.name
    codebuild_role_name            = aws_iam_role.codebuild.name
    codepipeline_role_name         = aws_iam_role.codepipeline.name
    kms_key_alias                  = aws_kms_alias.codepipeline.name
    log_group_name                 = aws_cloudwatch_log_group.codebuild.name
    sns_topic_name                 = aws_sns_topic.pipeline_notifications.name
  }
}

# Monitoring and Observability
output "monitoring_configuration" {
  description = "Monitoring and observability configuration"
  value = {
    log_group = {
      name              = aws_cloudwatch_log_group.codebuild.name
      arn               = aws_cloudwatch_log_group.codebuild.arn
      retention_in_days = aws_cloudwatch_log_group.codebuild.retention_in_days
    }
    sns_notifications = {
      topic_arn     = aws_sns_topic.pipeline_notifications.arn
      email_count   = length(aws_sns_topic_subscription.pipeline_email)
    }
    artifacts_lifecycle = {
      bucket_name    = aws_s3_bucket.codepipeline_artifacts.bucket
      expiration_days = var.artifact_retention_days
    }
  }
}

# Security Configuration
output "security_configuration" {
  description = "Security configuration details"
  value = {
    kms_encryption = {
      key_id    = aws_kms_key.codepipeline.key_id
      key_arn   = aws_kms_key.codepipeline.arn
      alias     = aws_kms_alias.codepipeline.name
    }
    s3_security = {
      bucket_name                 = aws_s3_bucket.codepipeline_artifacts.bucket
      versioning_enabled         = true
      encryption_enabled         = true
      public_access_blocked      = true
    }
    iam_roles = {
      codebuild_role_arn    = aws_iam_role.codebuild.arn
      codepipeline_role_arn = aws_iam_role.codepipeline.arn
    }
  }
}