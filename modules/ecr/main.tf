terraform {
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
  }
}

# Get current AWS account and region
data "aws_caller_identity" "current" {}
data "aws_region" "current" {}

# ECR repositories for different services
resource "aws_ecr_repository" "repositories" {
  for_each = toset(var.repository_names)
  
  name                 = "${var.name_prefix}/${each.value}"
  image_tag_mutability = var.image_tag_mutability

  image_scanning_configuration {
    scan_on_push = var.scan_on_push
  }

  encryption_configuration {
    encryption_type = "AES256"
  }

  tags = merge(var.tags, {
    Name = "${var.name_prefix}-${each.value}-ecr"
    Service = each.value
  })
}

# Lifecycle policies for each repository
resource "aws_ecr_lifecycle_policy" "policies" {
  for_each = aws_ecr_repository.repositories
  
  repository = each.value.name

  policy = jsonencode({
    rules = [
      {
        rulePriority = 1
        description  = "Keep last ${var.max_image_count} production images"
        selection = {
          tagStatus     = "tagged"
          tagPrefixList = ["v", "prod", "release"]
          countType     = "imageCountMoreThan"
          countNumber   = var.max_image_count
        }
        action = {
          type = "expire"
        }
      },
      {
        rulePriority = 2
        description  = "Keep last ${var.max_dev_image_count} development images"
        selection = {
          tagStatus     = "tagged"
          tagPrefixList = ["dev", "staging", "test"]
          countType     = "imageCountMoreThan"
          countNumber   = var.max_dev_image_count
        }
        action = {
          type = "expire"
        }
      },
      {
        rulePriority = 3
        description  = "Delete untagged images older than ${var.untagged_image_days} days"
        selection = {
          tagStatus   = "untagged"
          countType   = "sinceImagePushed"
          countUnit   = "days"
          countNumber = var.untagged_image_days
        }
        action = {
          type = "expire"
        }
      }
    ]
  })
}

# Cross-region replication for disaster recovery
resource "aws_ecr_replication_configuration" "main" {
  count = var.enable_cross_region_replication ? 1 : 0
  
  replication_configuration {
    rule {
      destination {
        region      = var.replication_region
        registry_id = data.aws_caller_identity.current.account_id
      }
      
      repository_filter {
        filter      = "${var.name_prefix}/*"
        filter_type = "PREFIX_MATCH"
      }
    }
  }
}

# Registry scanning configuration
resource "aws_ecr_registry_scanning_configuration" "main" {
  scan_type = "ENHANCED"

  rule {
    scan_frequency = "SCAN_ON_PUSH"
    repository_filter {
      filter      = "${var.name_prefix}/*"
      filter_type = "PREFIX_MATCH"
    }
  }

  rule {
    scan_frequency = "CONTINUOUS_SCAN"
    repository_filter {
      filter      = "${var.name_prefix}/*"
      filter_type = "PREFIX_MATCH"
    }
  }
}

# IAM policy for ECR access
resource "aws_iam_policy" "ecr_policy" {
  name        = "${var.name_prefix}-ecr-policy"
  description = "Policy for ECR access"

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Action = [
          "ecr:GetAuthorizationToken"
        ]
        Resource = "*"
      },
      {
        Effect = "Allow"
        Action = [
          "ecr:BatchCheckLayerAvailability",
          "ecr:GetDownloadUrlForLayer",
          "ecr:BatchGetImage",
          "ecr:DescribeRepositories",
          "ecr:DescribeImages",
          "ecr:ListImages"
        ]
        Resource = [for repo in aws_ecr_repository.repositories : repo.arn]
      }
    ]
  })

  tags = var.tags
}

# Pull-through cache rules for upstream registries
resource "aws_ecr_pull_through_cache_rule" "dockerhub" {
  count = var.enable_pull_through_cache ? 1 : 0
  
  ecr_repository_prefix = "dockerhub"
  upstream_registry_url = "registry-1.docker.io"
}

resource "aws_ecr_pull_through_cache_rule" "public_ecr" {
  count = var.enable_pull_through_cache ? 1 : 0
  
  ecr_repository_prefix = "ecr-public"
  upstream_registry_url = "public.ecr.aws"
}

# CloudWatch log group for ECR events
resource "aws_cloudwatch_log_group" "ecr_events" {
  name              = "/aws/ecr/${var.name_prefix}"
  retention_in_days = var.log_retention_days
  
  tags = merge(var.tags, {
    Name = "${var.name_prefix}-ecr-logs"
  })
}

# EventBridge rule for ECR image push events
resource "aws_cloudwatch_event_rule" "ecr_image_push" {
  name        = "${var.name_prefix}-ecr-image-push"
  description = "Capture ECR image push events"

  event_pattern = jsonencode({
    source      = ["aws.ecr"]
    detail-type = ["ECR Image Action"]
    detail = {
      action-type = ["PUSH"]
      repository-name = [for repo in aws_ecr_repository.repositories : repo.name]
    }
  })

  tags = var.tags
}

# SNS topic for ECR notifications
resource "aws_sns_topic" "ecr_notifications" {
  name = "${var.name_prefix}-ecr-notifications"
  
  tags = var.tags
}

# EventBridge target for ECR notifications
resource "aws_cloudwatch_event_target" "ecr_notifications" {
  rule      = aws_cloudwatch_event_rule.ecr_image_push.name
  target_id = "ECRNotificationTarget"
  arn       = aws_sns_topic.ecr_notifications.arn
}

# Allow EventBridge to publish to SNS
resource "aws_sns_topic_policy" "ecr_notifications" {
  arn = aws_sns_topic.ecr_notifications.arn

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Principal = {
          Service = "events.amazonaws.com"
        }
        Action = "sns:Publish"
        Resource = aws_sns_topic.ecr_notifications.arn
      }
    ]
  })
}

# CloudWatch alarms for repository size
resource "aws_cloudwatch_metric_alarm" "repository_size" {
  for_each = aws_ecr_repository.repositories
  
  alarm_name          = "${var.name_prefix}-ecr-${each.key}-size"
  comparison_operator = "GreaterThanThreshold"
  evaluation_periods  = "2"
  metric_name         = "RepositorySizeInBytes"
  namespace           = "AWS/ECR"
  period              = "300"
  statistic           = "Average"
  threshold           = var.repository_size_alarm_threshold
  alarm_description   = "ECR repository ${each.value.name} size is too large"
  treat_missing_data  = "notBreaching"

  dimensions = {
    RepositoryName = each.value.name
  }

  alarm_actions = [aws_sns_topic.ecr_notifications.arn]

  tags = var.tags
}