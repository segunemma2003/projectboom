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

# Use same module structure as production but with different variables
module "networking" {
  source = "../../modules/networking"
  
  name_prefix        = local.name_prefix
  vpc_cidr          = var.vpc_cidr
  availability_zones = local.availability_zones
  enable_nat_gateway = var.enable_nat_gateway
  
  tags = local.common_tags
}

module "security" {
  source = "../../modules/security"
  
  name_prefix      = local.name_prefix
  vpc_id          = module.networking.vpc_id
  app_port        = var.app_port
  websocket_port  = var.websocket_port
  
  tags = local.common_tags
}

module "storage" {
  source = "../../modules/storage"
  
  name_prefix = local.name_prefix
  
  tags = local.common_tags
}

module "iam" {
  source = "../../modules/iam"
  
  name_prefix = local.name_prefix
  s3_bucket_arns = [
    module.storage.media_bucket_arn,
    module.storage.static_bucket_arn
  ]
  
  tags = local.common_tags
}

module "database" {
  source = "../../modules/database/rds"
  
  name_prefix             = local.name_prefix
  vpc_id                 = module.networking.vpc_id
  subnet_ids             = module.networking.database_subnet_ids
  security_group_ids     = [module.security.rds_security_group_id]
  
  instance_class         = var.database_instance_class
  allocated_storage      = var.database_allocated_storage
  max_allocated_storage  = var.database_max_allocated_storage
  backup_retention_period = var.database_backup_retention_period
  multi_az              = var.database_multi_az
  
  monitoring_role_arn   = module.iam.rds_monitoring_role_arn
  
  tags = local.common_tags
}

module "redis" {
  source = "../../modules/database/redis"
  
  name_prefix        = local.name_prefix
  vpc_id            = module.networking.vpc_id
  subnet_ids        = module.networking.private_subnet_ids
  security_group_ids = [module.security.redis_security_group_id]
  
  node_type         = var.redis_node_type
  num_cache_nodes   = var.redis_num_cache_nodes
  
  tags = local.common_tags
}

module "ssl" {
  source = "../../modules/ssl"
  
  domain_name = var.domain_name
  zone_id     = data.aws_route53_zone.main.zone_id
  
  tags = local.common_tags
}

module "load_balancer" {
  source = "../../modules/load_balancer"
  
  name_prefix        = local.name_prefix
  vpc_id            = module.networking.vpc_id
  subnet_ids        = module.networking.public_subnet_ids
  security_group_ids = [module.security.alb_security_group_id]
  certificate_arn   = module.ssl.certificate_arn
  
  tags = local.common_tags
}

module "cloudfront" {
  source = "../../modules/cloudfront"
  
  name_prefix          = local.name_prefix
  domain_name         = var.domain_name
  s3_bucket_domain    = module.storage.media_bucket_domain_name
  alb_domain_name     = module.load_balancer.dns_name
  certificate_arn     = module.ssl.certificate_arn
  
  tags = local.common_tags
}

module "monitoring" {
  source = "../../modules/monitoring"
  
  name_prefix  = local.name_prefix
  cluster_name = "${local.name_prefix}-cluster"
  
  tags = local.common_tags
}

module "ecs" {
  source = "../../modules/ecs"
  
  name_prefix         = local.name_prefix
  cluster_name       = "${local.name_prefix}-cluster"
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
          value = var.environment == "development" ? "True" : "False"
        },
        {
          name  = "DATABASE_HOST"
          value = module.database.endpoint
        },
        {
          name  = "REDIS_HOST"
          value = module.redis.primary_endpoint
        },
        {
          name  = "S3_BUCKET_NAME"
          value = module.storage.media_bucket_name
        },
        {
          name  = "AWS_DEFAULT_REGION"
          value = var.aws_region
        },
        {
          name  = "ALLOWED_HOSTS"
          value = var.domain_name
        }
      ]
      secrets = [
        {
          name      = "DATABASE_PASSWORD"
          valueFrom = module.database.password_secret_arn
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
          name  = "REDIS_HOST"
          value = module.redis.primary_endpoint
        },
        {
          name  = "AWS_DEFAULT_REGION"
          value = var.aws_region
        }
      ]
      secrets = []
      health_check     = ["CMD-SHELL", "curl -f http://localhost:${var.websocket_port}/ws/health/ || exit 1"]
      target_group_arn = module.load_balancer.websocket_target_group_arn
    }
  }
  
  execution_role_arn = module.iam.ecs_execution_role_arn
  task_role_arn     = module.iam.ecs_task_role_arn
  security_group_ids = [module.security.ecs_security_group_id]
  subnet_ids        = module.networking.private_subnet_ids
  log_group_name    = module.monitoring.log_group_name
  
  # Add target group dependency
  target_group_arns = [
    module.load_balancer.api_target_group_arn,
    module.load_balancer.websocket_target_group_arn
  ]
  
  tags = local.common_tags
}

module "autoscaling" {
  source = "../../modules/autoscaling"
  
  name_prefix   = local.name_prefix
  cluster_name  = module.ecs.cluster_name
  service_names = module.ecs.service_names
  
  min_capacity = var.autoscaling_min_capacity
  max_capacity = var.autoscaling_max_capacity
  
  tags = local.common_tags
}

module "alerts" {
  source = "../../modules/alerts"
  
  name_prefix    = local.name_prefix
  alert_email    = var.alert_email
  slack_webhook  = var.slack_webhook_url
  
  tags = local.common_tags
}