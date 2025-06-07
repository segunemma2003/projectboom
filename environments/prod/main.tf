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
    tags = local.common_tags
  }
}

# Data sources
data "aws_availability_zones" "available" {
  state = "available"
}

data "aws_caller_identity" "current" {}

data "aws_route53_zone" "main" {
  name         = var.domain_name
  private_zone = false
}

# Local values
locals {
  common_tags = {
    Environment = var.environment
    Project     = var.project_name
    ManagedBy   = "terraform"
    Owner       = var.owner
  }
  
  name_prefix = "${var.project_name}-${var.environment}"
  availability_zones = slice(data.aws_availability_zones.available.names, 0, 3)
}

# Networking Module - No dependencies
module "networking" {
  source = "../../modules/networking"
  
  name_prefix        = local.name_prefix
  vpc_cidr          = var.vpc_cidr
  availability_zones = local.availability_zones
  enable_nat_gateway = var.enable_nat_gateway
  
  tags = local.common_tags
}

# Security Module - Depends on networking only
module "security" {
  source = "../../modules/security"
  
  name_prefix      = local.name_prefix
  vpc_id          = module.networking.vpc_id
  app_port        = var.app_port
  websocket_port  = var.websocket_port
  
  tags = local.common_tags
}

# Storage Module - Enhanced for recordings
module "storage" {
  source = "../../modules/storage"
  
  name_prefix = local.name_prefix
  
  tags = local.common_tags
}

# Additional S3 bucket for LiveKit recordings
resource "aws_s3_bucket" "recordings" {
  bucket = "${local.name_prefix}-recordings-${random_id.bucket_suffix.hex}"
  tags   = local.common_tags
}

resource "random_id" "bucket_suffix" {
  byte_length = 4
}

resource "aws_s3_bucket_versioning" "recordings" {
  bucket = aws_s3_bucket.recordings.id
  versioning_configuration {
    status = "Enabled"
  }
}

resource "aws_s3_bucket_server_side_encryption_configuration" "recordings" {
  bucket = aws_s3_bucket.recordings.id

  rule {
    apply_server_side_encryption_by_default {
      sse_algorithm = "AES256"
    }
  }
}

resource "aws_s3_bucket_lifecycle_configuration" "recordings" {
  bucket = aws_s3_bucket.recordings.id

  rule {
    id     = "recordings_lifecycle"
    status = "Enabled"

    transition {
      days          = 30
      storage_class = "STANDARD_IA"
    }

    transition {
      days          = 90
      storage_class = "GLACIER"
    }
  }
}

# Enhanced IAM Module
module "iam" {
  source = "../../modules/iam"
  
  name_prefix = local.name_prefix
  s3_bucket_arns = [
    module.storage.media_bucket_arn,
    module.storage.static_bucket_arn,
    aws_s3_bucket.recordings.arn
  ]
  
  tags = local.common_tags
}

# Additional IAM role for RDS Proxy
resource "aws_iam_role" "rds_proxy" {
  name = "${local.name_prefix}-rds-proxy-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action = "sts:AssumeRole"
        Effect = "Allow"
        Principal = {
          Service = "rds.amazonaws.com"
        }
      }
    ]
  })

  tags = local.common_tags
}

resource "aws_iam_role_policy" "rds_proxy" {
  name = "${local.name_prefix}-rds-proxy-policy"
  role = aws_iam_role.rds_proxy.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Action = [
          "secretsmanager:GetSecretValue",
          "secretsmanager:DescribeSecret"
        ]
        Resource = module.database.master_password_secret_arn
      }
    ]
  })
}

# Aurora Database Module - Enhanced
module "database" {
  source = "../../modules/database/aurora"
  
  name_prefix             = local.name_prefix
  vpc_id                 = module.networking.vpc_id
  subnet_ids             = module.networking.database_subnet_ids
  security_group_ids     = [module.security.rds_security_group_id]
  
  writer_count           = var.database_writer_count
  reader_count           = var.database_reader_count
  min_capacity           = var.database_min_capacity
  max_capacity           = var.database_max_capacity
  backup_retention_period = var.database_backup_retention_period
  deletion_protection    = var.database_deletion_protection
  enable_global_cluster  = var.enable_global_cluster
  
  monitoring_role_arn    = module.iam.rds_monitoring_role_arn
  proxy_role_arn        = aws_iam_role.rds_proxy.arn
  
  tags = local.common_tags
}

# Redis Cluster Module - Enhanced
module "redis" {
  source = "../../modules/database/redis-cluster"
  
  name_prefix        = local.name_prefix
  vpc_id            = module.networking.vpc_id
  subnet_ids        = module.networking.private_subnet_ids
  security_group_ids = [module.security.redis_security_group_id]
  
  node_type          = var.redis_node_type
  num_node_groups    = var.redis_num_node_groups
  replicas_per_node_group = var.redis_replicas_per_node_group
  
  session_node_type     = var.redis_session_node_type
  session_num_node_groups = var.redis_session_num_node_groups
  
  realtime_node_type      = var.redis_realtime_node_type
  realtime_num_node_groups = var.redis_realtime_num_node_groups
  
  auth_token_enabled     = true
  notification_topic_arn = module.alerts.topic_arn
  alarm_actions         = [module.alerts.topic_arn]
  
  tags = local.common_tags
}

# SSL Certificate Module
module "ssl" {
  source = "../../modules/ssl"
  
  domain_name = var.domain_name
  zone_id     = data.aws_route53_zone.main.zone_id
  
  tags = local.common_tags
}

# Load Balancer Module
module "load_balancer" {
  source = "../../modules/load_balancer"
  
  name_prefix        = local.name_prefix
  vpc_id            = module.networking.vpc_id
  subnet_ids        = module.networking.public_subnet_ids
  security_group_ids = [module.security.alb_security_group_id]
  certificate_arn   = module.ssl.certificate_arn
  
  tags = local.common_tags
}

# API Gateway Module - NEW
module "api_gateway" {
  source = "../../modules/api_gateway"
  
  name_prefix         = local.name_prefix
  vpc_id             = module.networking.vpc_id
  private_subnet_ids = module.networking.private_subnet_ids
  domain_name        = var.domain_name
  certificate_arn    = module.ssl.certificate_arn
  environment        = var.environment
  
  alb_listener_arn   = module.load_balancer.https_listener_arn
  alb_dns_name       = module.load_balancer.dns_name
  
  # Rate limiting for 40M users
  throttle_burst_limit = var.api_throttle_burst_limit
  throttle_rate_limit  = var.api_throttle_rate_limit
  waf_rate_limit      = var.waf_rate_limit
  
  # Usage plans
  premium_quota_limit           = var.premium_quota_limit
  premium_throttle_burst_limit  = var.premium_throttle_burst_limit
  premium_throttle_rate_limit   = var.premium_throttle_rate_limit
  
  standard_quota_limit          = var.standard_quota_limit
  standard_throttle_burst_limit = var.standard_throttle_burst_limit
  standard_throttle_rate_limit  = var.standard_throttle_rate_limit
  
  alarm_actions = [module.alerts.topic_arn]
  
  tags = local.common_tags
}

# LiveKit Module - NEW
module "livekit" {
  source = "../../modules/livekit"
  
  name_prefix          = local.name_prefix
  vpc_id              = module.networking.vpc_id
  public_subnet_ids   = module.networking.public_subnet_ids
  private_subnet_ids  = module.networking.private_subnet_ids
  
  cluster_id          = module.ecs.cluster_id
  cluster_name        = module.ecs.cluster_name
  execution_role_arn  = module.iam.ecs_execution_role_arn
  task_role_arn       = module.iam.ecs_task_role_arn
  
  certificate_arn     = module.ssl.certificate_arn
  domain_name         = var.domain_name
  redis_endpoint      = module.redis.main_cluster_configuration_endpoint
  redis_security_group_ids = [module.security.redis_security_group_id]
  aws_region          = var.aws_region
  
  # LiveKit configuration for 40M users
  livekit_cpu           = var.livekit_cpu
  livekit_memory        = var.livekit_memory
  livekit_desired_count = var.livekit_desired_count
  livekit_min_capacity  = var.livekit_min_capacity
  livekit_max_capacity  = var.livekit_max_capacity
  
  enable_recording        = var.enable_livekit_recording
  recordings_bucket_name  = aws_s3_bucket.recordings.bucket
  
  tags = local.common_tags
}

# CloudFront Module
module "cloudfront" {
  source = "../../modules/cloudfront"
  
  name_prefix          = local.name_prefix
  domain_name         = var.domain_name
  s3_bucket_domain    = module.storage.media_bucket_domain_name
  alb_domain_name     = module.load_balancer.dns_name
  certificate_arn     = module.ssl.certificate_arn
  
  tags = local.common_tags
}

# Enhanced Monitoring Module
module "monitoring" {
  source = "../../modules/monitoring"
  
  name_prefix              = local.name_prefix
  cluster_name            = module.ecs.cluster_name
  environment             = var.environment
  aws_region              = var.aws_region
  
  # Add these missing variables
  alb_full_name           = module.load_balancer.alb_full_name
  database_cluster_name   = module.database.cluster_id
  redis_endpoint          = module.redis.main_cluster_configuration_endpoint
  
  # Business metrics thresholds for 40M users
  min_active_users_threshold    = var.min_active_users_threshold
  max_video_calls_threshold     = var.max_video_calls_threshold
  max_message_queue_length      = var.max_message_queue_length
  max_database_connections      = var.max_database_connections
  
  enable_cost_monitoring        = var.enable_cost_monitoring
  cost_alert_threshold         = var.cost_alert_threshold
  enable_custom_metrics        = var.enable_custom_metrics
  critical_alert_emails        = var.critical_alert_emails
  
  alarm_actions = [module.alerts.topic_arn]
  
  tags = local.common_tags
}

# ECS Compute Module - Enhanced
module "ecs" {
   source = "../../modules/ecs"
  
  name_prefix         = local.name_prefix
  cluster_name       = "${local.name_prefix}-cluster"
  environment        = var.environment  # ADD THIS
  aws_region         = var.aws_region
  services = {
    api = {
      image         = "${var.ecr_repository_url}/api:latest"
      cpu           = var.api_cpu
      memory        = var.api_memory
      port          = var.app_port
      desired_count = var.api_desired_count
      environment = [
        {
          name  = "ENVIRONMENT"
          value = var.environment
        },
        {
          name  = "DEBUG"
          value = "False"
        },
        {
          name  = "DATABASE_HOST"
          value = module.database.proxy_endpoint
        },
        {
          name  = "DATABASE_READER_HOST"
          value = module.database.cluster_reader_endpoint
        },
        {
          name  = "REDIS_MAIN_HOST"
          value = module.redis.main_cluster_configuration_endpoint
        },
        {
          name  = "REDIS_SESSIONS_HOST"
          value = module.redis.sessions_cluster_configuration_endpoint
        },
        {
          name  = "REDIS_REALTIME_HOST"
          value = module.redis.realtime_cluster_configuration_endpoint
        },
        {
          name  = "S3_BUCKET_NAME"
          value = module.storage.media_bucket_name
        },
        {
          name  = "S3_RECORDINGS_BUCKET"
          value = aws_s3_bucket.recordings.bucket
        },
        {
          name  = "AWS_DEFAULT_REGION"
          value = var.aws_region
        },
        {
          name  = "ALLOWED_HOSTS"
          value = var.domain_name
        },
        {
          name  = "LIVEKIT_API_HOST"
          value = "https://livekit.${var.domain_name}"
        }
      ]
      secrets = [
        {
          name      = "DATABASE_PASSWORD"
          valueFrom = module.database.master_password_secret_arn
        },
        {
          name      = "REDIS_AUTH_TOKEN"
          valueFrom = module.redis.auth_token_secret_arn
        },
        {
          name      = "LIVEKIT_CREDENTIALS"
          valueFrom = module.livekit.api_key_secret_arn
        }
      ]
      health_check     = ["CMD-SHELL", "curl -f http://localhost:${var.app_port}/health/ || exit 1"]
      target_group_arn = module.load_balancer.api_target_group_arn
    }
    
    websocket = {
      image         = "${var.ecr_repository_url}/websocket:latest"
      cpu           = var.websocket_cpu
      memory        = var.websocket_memory
      port          = var.websocket_port
      desired_count = var.websocket_desired_count
      environment = [
        {
          name  = "ENVIRONMENT"
          value = var.environment
        },
        {
          name  = "REDIS_REALTIME_HOST"
          value = module.redis.realtime_cluster_configuration_endpoint
        },
        {
          name  = "REDIS_SESSIONS_HOST"
          value = module.redis.sessions_cluster_configuration_endpoint
        },
        {
          name  = "AWS_DEFAULT_REGION"
          value = var.aws_region
        }
      ]
      secrets = [
        {
          name      = "REDIS_AUTH_TOKEN"
          valueFrom = module.redis.auth_token_secret_arn
        }
      ]
      health_check     = ["CMD-SHELL", "curl -f http://localhost:${var.websocket_port}/ws/health/ || exit 1"]
      target_group_arn = module.load_balancer.websocket_target_group_arn
    }
  }
  
  execution_role_arn = module.iam.ecs_execution_role_arn
  task_role_arn     = module.iam.ecs_task_role_arn
  security_group_ids = [module.security.ecs_security_group_id]
  subnet_ids        = module.networking.private_subnet_ids
  log_group_name    = module.monitoring.log_group_name
  
  
  target_group_arns = [
    module.load_balancer.api_target_group_arn,
    module.load_balancer.websocket_target_group_arn
  ]
  
  tags = local.common_tags

  depends_on = [module.load_balancer]
}

# Auto Scaling Module
module "autoscaling" {
  source = "../../modules/autoscaling"
  
  name_prefix   = local.name_prefix
  cluster_name  = module.ecs.cluster_name
  service_names = module.ecs.service_names
  
  min_capacity = var.autoscaling_min_capacity
  max_capacity = var.autoscaling_max_capacity
  
  tags = local.common_tags
}

# SNS Alerts Module
module "alerts" {
  source = "../../modules/alerts"
  
  name_prefix    = local.name_prefix
  alert_email    = var.alert_email
  slack_webhook  = var.slack_webhook_url
  
  tags = local.common_tags
}

# Route 53 Records
resource "aws_route53_record" "main" {
  zone_id = data.aws_route53_zone.main.zone_id
  name    = var.domain_name
  type    = "A"

  alias {
    name                   = module.cloudfront.domain_name
    zone_id                = module.cloudfront.hosted_zone_id
    evaluate_target_health = false
  }
}

resource "aws_route53_record" "api" {
  zone_id = data.aws_route53_zone.main.zone_id
  name    = "api.${var.domain_name}"
  type    = "A"

  alias {
    name                   = module.api_gateway.api_gateway_regional_domain_name
    zone_id                = module.api_gateway.api_gateway_regional_zone_id
    evaluate_target_health = false
  }
}

resource "aws_route53_record" "livekit" {
  zone_id = data.aws_route53_zone.main.zone_id
  name    = "livekit.${var.domain_name}"
  type    = "A"

  alias {
    name                   = module.livekit.alb_dns_name
    zone_id                = module.livekit.alb_zone_id
    evaluate_target_health = true
  }
}

resource "aws_route53_record" "turn" {
  zone_id = data.aws_route53_zone.main.zone_id
  name    = "turn.${var.domain_name}"
  type    = "A"

  alias {
    name                   = module.livekit.nlb_dns_name
    zone_id                = module.livekit.nlb_zone_id
    evaluate_target_health = true
  }
}

resource "aws_route53_record" "cdn" {
  zone_id = data.aws_route53_zone.main.zone_id
  name    = "cdn.${var.domain_name}"
  type    = "A"

  alias {
    name                   = module.cloudfront.domain_name
    zone_id                = module.cloudfront.hosted_zone_id
    evaluate_target_health = false
  }
}