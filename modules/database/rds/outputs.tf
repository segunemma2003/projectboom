output "endpoint" {
  description = "RDS instance endpoint"
  value       = aws_db_instance.main.endpoint
}

output "password_secret_arn" {
  description = "Secret ARN for database password"
  value       = aws_secretsmanager_secret.db_password.arn
}