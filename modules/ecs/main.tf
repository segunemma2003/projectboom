resource "aws_ecs_cluster" "main" {
  name = var.cluster_name

  configuration {
    execute_command_configuration {
      logging = "OVERRIDE"
      
      log_configuration {
        cloud_watch_encryption_enabled = true
        cloud_watch_log_group_name     = var.log_group_name
      }
    }
  }

  tags = var.tags
}

resource "aws_ecs_cluster_capacity_providers" "main" {
  cluster_name = aws_ecs_cluster.main.name

  capacity_providers = ["FARGATE", "FARGATE_SPOT"]

  default_capacity_provider_strategy {
    base              = var.fargate_base
    weight            = var.fargate_weight
    capacity_provider = "FARGATE"
  }

  default_capacity_provider_strategy {
    base              = var.fargate_spot_base
    weight            = var.fargate_spot_weight
    capacity_provider = "FARGATE_SPOT"
  }
}

resource "aws_ecs_task_definition" "app" {
  for_each = var.services

  family                   = "${var.name_prefix}-${each.key}"
  network_mode             = "awsvpc"
  requires_compatibilities = ["FARGATE"]
  cpu                      = each.value.cpu
  memory                   = each.value.memory
  execution_role_arn       = var.execution_role_arn
  task_role_arn           = var.task_role_arn

  container_definitions = jsonencode([
    {
      name  = each.key
      image = each.value.image
      
      portMappings = [
        {
          containerPort = each.value.port
          protocol      = "tcp"
        }
      ]

      environment = each.value.environment
      secrets     = each.value.secrets

      logConfiguration = {
        logDriver = "awslogs"
        options = {
          awslogs-group         = var.log_group_name
          awslogs-region        = var.aws_region
          awslogs-stream-prefix = each.key
        }
      }

      healthCheck = {
        command     = each.value.health_check
        interval    = 30
        timeout     = 5
        retries     = 3
        startPeriod = 60
      }

      essential = true
    }
  ])

  tags = merge(var.tags, {
    Name = "${var.name_prefix}-${each.key}-task"
  })
}

resource "aws_ecs_service" "app" {
  for_each = var.services

  name            = "${var.name_prefix}-${each.key}"
  cluster         = aws_ecs_cluster.main.id
  task_definition = aws_ecs_task_definition.app[each.key].arn
  desired_count   = each.value.desired_count

  # Use launch_type instead of capacity_provider_strategy for simplicity
  launch_type = "FARGATE"

  network_configuration {
    security_groups  = var.security_group_ids
    subnets          = var.subnet_ids
    assign_public_ip = false
  }

  dynamic "load_balancer" {
    for_each = each.value.target_group_arn != null && each.value.target_group_arn != "" ? [1] : []
    content {
      target_group_arn = each.value.target_group_arn
      container_name   = each.key
      container_port   = each.value.port
    }
  }

  # REMOVED: deployment_configuration block completely
  # Modern AWS provider uses default values:
  # - maximum_percent = 200
  # - minimum_healthy_percent = 100

  tags = merge(var.tags, {
    Name = "${var.name_prefix}-${each.key}-service"
  })

  lifecycle {
    ignore_changes = [desired_count]
  }
}
