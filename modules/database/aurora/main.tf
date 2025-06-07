resource "aws_db_subnet_group" "main" {
  name       = "${var.name_prefix}-aurora-subnet-group"
  subnet_ids = var.subnet_ids

  tags = merge(var.tags, {
    Name = "${var.name_prefix}-aurora-subnet-group"
  })
}

resource "aws_db_parameter_group" "main" {
  name   = "${var.name_prefix}-aurora-postgres-params"
  family = "aurora-postgresql15"

  parameter {
    name  = "shared_preload_libraries"
    value = "pg_stat_statements,pg_hint_plan"
  }

  parameter {
    name  = "log_statement"
    value = "all"
  }

  parameter {
    name  = "log_min_duration_statement"
    value = "1000"
  }

  parameter {
    name  = "max_connections"
    value = "LEAST({DBInstanceClassMemory/9531392},5000)"
  }

  tags = var.tags
}

resource "random_password" "master_password" {
  length  = 32
  special = true
}

resource "aws_secretsmanager_secret" "master_password" {
  name = "${var.name_prefix}/aurora/master-password"
  tags = var.tags
}

resource "aws_secretsmanager_secret_version" "master_password" {
  secret_id     = aws_secretsmanager_secret.master_password.id
  secret_string = random_password.master_password.result
}

# Global Cluster (optional)
resource "aws_rds_global_cluster" "main" {
  count                     = var.enable_global_cluster ? 1 : 0
  global_cluster_identifier = "${var.name_prefix}-global"
  engine                   = "aurora-postgresql"
  engine_version           = "15.4"
  database_name            = "socialmedia"
  deletion_protection      = var.deletion_protection
}

# Primary Aurora Cluster
resource "aws_rds_cluster" "main" {
  cluster_identifier = "${var.name_prefix}-aurora-cluster"
  
  engine                  = "aurora-postgresql"
  engine_mode            = "provisioned"
  engine_version         = "15.4"
  database_name          = "socialmedia"
  master_username        = "dbadmin"
  master_password        = random_password.master_password.result
  
  db_subnet_group_name   = aws_db_subnet_group.main.name
  vpc_security_group_ids = var.security_group_ids
  db_cluster_parameter_group_name = aws_db_parameter_group.main.name

  backup_retention_period = var.backup_retention_period
  preferred_backup_window = "03:00-04:00"
  preferred_maintenance_window = "sun:04:00-sun:05:00"
  
  deletion_protection = var.deletion_protection
  skip_final_snapshot = false
  final_snapshot_identifier = "${var.name_prefix}-final-snapshot-${formatdate("YYYY-MM-DD-hhmm", timestamp())}"
  
  enabled_cloudwatch_logs_exports = ["postgresql"]
  
  # Serverless v2 scaling
  serverlessv2_scaling_configuration {
    max_capacity = var.max_capacity
    min_capacity = var.min_capacity
  }

  global_cluster_identifier = var.enable_global_cluster ? aws_rds_global_cluster.main[0].id : null

  tags = merge(var.tags, {
    Name = "${var.name_prefix}-aurora-cluster"
  })

  lifecycle {
    ignore_changes = [
      final_snapshot_identifier,
      master_password
    ]
  }
}

# Writer instances
resource "aws_rds_cluster_instance" "writer" {
  count = var.writer_count
  
  identifier           = "${var.name_prefix}-writer-${count.index + 1}"
  cluster_identifier   = aws_rds_cluster.main.id
  instance_class       = "db.serverless"
  engine               = aws_rds_cluster.main.engine
  engine_version       = aws_rds_cluster.main.engine_version
  
  performance_insights_enabled = true
  monitoring_interval          = 60
  monitoring_role_arn         = var.monitoring_role_arn
  
  tags = merge(var.tags, {
    Name = "${var.name_prefix}-writer-${count.index + 1}"
    Role = "writer"
  })
}

# Reader instances
resource "aws_rds_cluster_instance" "reader" {
  count = var.reader_count
  
  identifier           = "${var.name_prefix}-reader-${count.index + 1}"
  cluster_identifier   = aws_rds_cluster.main.id
  instance_class       = "db.serverless"
  engine               = aws_rds_cluster.main.engine
  engine_version       = aws_rds_cluster.main.engine_version
  
  performance_insights_enabled = true
  monitoring_interval          = 60
  monitoring_role_arn         = var.monitoring_role_arn
  
  tags = merge(var.tags, {
    Name = "${var.name_prefix}-reader-${count.index + 1}"
    Role = "reader"
  })
}

# RDS Proxy for connection pooling - FIXED
resource "aws_db_proxy" "main" {
  name                   = "${var.name_prefix}-aurora-proxy"
  engine_family         = "POSTGRESQL"
  
  auth {
    auth_scheme = "SECRETS"
    secret_arn  = aws_secretsmanager_secret.master_password.arn
  }
  
  role_arn               = var.proxy_role_arn
  vpc_subnet_ids         = var.subnet_ids
  vpc_security_group_ids = var.security_group_ids
  
  require_tls         = true
  idle_client_timeout = 1800

  tags = var.tags
}

resource "aws_db_proxy_default_target_group" "main" {
  db_proxy_name = aws_db_proxy.main.name

  connection_pool_config {
    connection_borrow_timeout    = 120
    max_connections_percent      = 100
    max_idle_connections_percent = 50
    session_pinning_filters      = ["EXCLUDE_VARIABLE_SETS"]
  }
}

resource "aws_db_proxy_target" "main" {
  db_cluster_identifier = aws_rds_cluster.main.cluster_identifier
  db_proxy_name         = aws_db_proxy.main.name
  target_group_name     = aws_db_proxy_default_target_group.main.name
}