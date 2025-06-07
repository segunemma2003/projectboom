output "media_bucket_name" {
  description = "Media bucket name"
  value       = aws_s3_bucket.media.bucket
}

output "media_bucket_arn" {
  description = "Media bucket ARN"
  value       = aws_s3_bucket.media.arn
}

output "media_bucket_domain_name" {
  description = "Media bucket domain name"
  value       = aws_s3_bucket.media.bucket_domain_name
}

output "static_bucket_name" {
  description = "Static bucket name"
  value       = aws_s3_bucket.static.bucket
}

output "static_bucket_arn" {
  description = "Static bucket ARN"
  value       = aws_s3_bucket.static.arn
}
