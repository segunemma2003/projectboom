output "cluster_id" {
  description = "Aurora cluster identifier"
  value       = aws_rds_cluster.main.cluster_identifier
}

output "cluster_endpoint" {
  description = "Aurora cluster endpoint"
  value       = aws_rds_cluster.main.endpoint
}

output "cluster_reader_endpoint" {
  description = "Aurora cluster reader endpoint"
  value       = aws_rds_cluster.main.reader_endpoint
}

output "proxy_endpoint" {
  description = "RDS Proxy endpoint"
  value       = aws_db_proxy.main.endpoint
}

output "master_password_secret_arn" {
  description = "Secret ARN for master password"
  value       = aws_secretsmanager_secret.master_password.arn
}

output "cluster_port" {
  description = "Aurora cluster port"
  value       = aws_rds_cluster.main.port
}