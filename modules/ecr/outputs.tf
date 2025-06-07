output "repository_urls" {
  description = "ECR repository URLs"
  value = {
    for k, v in aws_ecr_repository.repositories : k => v.repository_url
  }
}

output "repository_arns" {
  description = "ECR repository ARNs"
  value = {
    for k, v in aws_ecr_repository.repositories : k => v.arn
  }
}

output "repository_names" {
  description = "ECR repository names"
  value = {
    for k, v in aws_ecr_repository.repositories : k => v.name
  }
}

output "ecr_policy_arn" {
  description = "ECR IAM policy ARN"
  value       = aws_iam_policy.ecr_policy.arn
}

output "notifications_topic_arn" {
  description = "SNS topic ARN for ECR notifications"
  value       = aws_sns_topic.ecr_notifications.arn
}

output "registry_id" {
  description = "ECR registry ID"
  value       = data.aws_caller_identity.current.account_id
}