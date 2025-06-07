
# LiveKit configuration secrets
resource "random_password" "livekit_api_key" {
  length  = 32
  special = false
}

resource "random_password" "livekit_api_secret" {
  length  = 64
  special = false
}

resource "aws_secretsmanager_secret" "livekit_credentials" {
  name                    = "${var.name_prefix}/livekit/credentials"
  recovery_window_in_days = 7
  tags                    = var.tags
}

resource "aws_secretsmanager_secret_version" "livekit_credentials" {
  secret_id = aws_secretsmanager_secret.livekit_credentials.id
  secret_string = jsonencode({
    api_key    = random_password.livekit_api_key.result
    api_secret = random_password.livekit_api_secret.result
  })
}

# Application Load Balancer for LiveKit
resource "aws_lb" "livekit" {
  name               = "${var.name_prefix}-livekit-alb"
  internal           = false
  load_balancer_type = "application"
  security_groups    = [aws_security_group.livekit_alb.id]
  subnets            = var.public_subnet_ids

  enable_deletion_protection = false

  tags = merge(var.tags, {
    Name = "${var.name_prefix}-livekit-alb"
  })
}

# Network Load Balancer for TURN/STUN traffic
resource "aws_lb" "livekit_turn" {
  name               = "${var.name_prefix}-livekit-nlb"
  internal           = false
  load_balancer_type = "network"
  subnets            = var.public_subnet_ids

  enable_deletion_protection = false

  tags = merge(var.tags, {
    Name = "${var.name_prefix}-livekit-nlb"
  })
}

# Target groups for LiveKit services
resource "aws_lb_target_group" "livekit_http" {
  name     = "${var.name_prefix}-livekit-http"
  port     = 7880
  protocol = "HTTP"
  vpc_id   = var.vpc_id

  health_check {
    enabled             = true
    healthy_threshold   = 2
    interval            = 30
    matcher             = "200"
    path                = "/validate"
    port                = "traffic-port"
    protocol            = "HTTP"
    timeout             = 5
    unhealthy_threshold = 3
  }

  tags = merge(var.tags, {
    Name = "${var.name_prefix}-livekit-http-tg"
  })
}

resource "aws_lb_target_group" "livekit_turn_tcp" {
  name     = "${var.name_prefix}-livekit-turn-tcp"
  port     = 443
  protocol = "TCP"
  vpc_id   = var.vpc_id

  health_check {
    enabled             = true
    healthy_threshold   = 2
    interval            = 30
    port                = 7880
    protocol            = "HTTP"
    path                = "/validate"
    timeout             = 5
    unhealthy_threshold = 3
  }

  tags = merge(var.tags, {
    Name = "${var.name_prefix}-livekit-turn-tcp-tg"
  })
}

resource "aws_lb_target_group" "livekit_turn_udp" {
  name     = "${var.name_prefix}-livekit-turn-udp"
  port     = 443
  protocol = "UDP"
  vpc_id   = var.vpc_id

  health_check {
    enabled             = true
    healthy_threshold   = 2
    interval            = 30
    port                = 7880
    protocol            = "HTTP"
    path                = "/validate"
    timeout             = 5
    unhealthy_threshold = 3
  }

  tags = merge(var.tags, {
    Name = "${var.name_prefix}-livekit-turn-udp-tg"
  })
}

# ALB Listeners
resource "aws_lb_listener" "livekit_https" {
  load_balancer_arn = aws_lb.livekit.arn
  port              = "443"
  protocol          = "HTTPS"
  ssl_policy        = "ELBSecurityPolicy-TLS-1-2-2017-01"
  certificate_arn   = var.certificate_arn

  default_action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.livekit_http.arn
  }
}

resource "aws_lb_listener" "livekit_http" {
  load_balancer_arn = aws_lb.livekit.arn
  port              = "80"
  protocol          = "HTTP"

  default_action {
    type = "redirect"

    redirect {
      port        = "443"
      protocol    = "HTTPS"
      status_code = "HTTP_301"
    }
  }
}

# NLB Listeners for TURN traffic
resource "aws_lb_listener" "livekit_turn_tcp" {
  load_balancer_arn = aws_lb.livekit_turn.arn
  port              = "443"
  protocol          = "TCP"

  default_action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.livekit_turn_tcp.arn
  }
}

resource "aws_lb_listener" "livekit_turn_udp" {
  load_balancer_arn = aws_lb.livekit_turn.arn
  port              = "443"
  protocol          = "UDP"

  default_action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.livekit_turn_udp.arn
  }
}

# Security Groups
resource "aws_security_group" "livekit_alb" {
  name_prefix = "${var.name_prefix}-livekit-alb-"
  vpc_id      = var.vpc_id

  ingress {
    from_port   = 80
    to_port     = 80
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  ingress {
    from_port   = 443
    to_port     = 443
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = merge(var.tags, {
    Name = "${var.name_prefix}-livekit-alb-sg"
  })

  lifecycle {
    create_before_destroy = true
  }
}

resource "aws_security_group" "livekit_ecs" {
  name_prefix = "${var.name_prefix}-livekit-ecs-"
  vpc_id      = var.vpc_id

  # HTTP traffic from ALB
  ingress {
    from_port       = 7880
    to_port         = 7880
    protocol        = "tcp"
    security_groups = [aws_security_group.livekit_alb.id]
  }

  # TURN/STUN traffic
  ingress {
    from_port   = 443
    to_port     = 443
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  ingress {
    from_port   = 443
    to_port     = 443
    protocol    = "udp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  # RTP port range for media
  ingress {
    from_port   = 50000
    to_port     = 60000
    protocol    = "udp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  # Redis access
  ingress {
    from_port       = 6379
    to_port         = 6379
    protocol        = "tcp"
    security_groups = var.redis_security_group_ids
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = merge(var.tags, {
    Name = "${var.name_prefix}-livekit-ecs-sg"
  })

  lifecycle {
    create_before_destroy = true
  }
}

# ECS Task Definition for LiveKit
resource "aws_ecs_task_definition" "livekit" {
  family                   = "${var.name_prefix}-livekit"
  network_mode             = "awsvpc"
  requires_compatibilities = ["FARGATE"]
  cpu                      = var.livekit_cpu
  memory                   = var.livekit_memory
  execution_role_arn       = var.execution_role_arn
  task_role_arn           = var.task_role_arn

  container_definitions = jsonencode([
    {
      name  = "livekit"
      image = var.livekit_image
      
      portMappings = [
        {
          containerPort = 7880
          protocol      = "tcp"
          name          = "http"
        },
        {
          containerPort = 443
          protocol      = "tcp"
          name          = "turn-tcp"
        },
        {
          containerPort = 443
          protocol      = "udp"
          name          = "turn-udp"
        }
      ]

      environment = [
        {
          name  = "LIVEKIT_CONFIG_BODY"
          value = local.livekit_config
        },
        {
          name  = "REDIS_URL"
          value = "redis://${var.redis_endpoint}:6379"
        }
      ]

      secrets = [
        {
          name      = "LIVEKIT_KEYS"
          valueFrom = aws_secretsmanager_secret.livekit_credentials.arn
        }
      ]

      logConfiguration = {
        logDriver = "awslogs"
        options = {
          awslogs-group         = aws_cloudwatch_log_group.livekit.name
          awslogs-region        = var.aws_region
          awslogs-stream-prefix = "livekit"
        }
      }

      healthCheck = {
        command     = ["CMD-SHELL", "curl -f http://localhost:7880/validate || exit 1"]
        interval    = 30
        timeout     = 5
        retries     = 3
        startPeriod = 60
      }

      essential = true
    }
  ])

  tags = merge(var.tags, {
    Name = "${var.name_prefix}-livekit-task"
  })
}

# ECS Service for LiveKit
resource "aws_ecs_service" "livekit" {
  name            = "${var.name_prefix}-livekit"
  cluster         = var.cluster_id
  task_definition = aws_ecs_task_definition.livekit.arn
  desired_count   = var.livekit_desired_count
  launch_type     = "FARGATE"

  network_configuration {
    security_groups  = [aws_security_group.livekit_ecs.id]
    subnets          = var.private_subnet_ids
    assign_public_ip = false
  }

  load_balancer {
    target_group_arn = aws_lb_target_group.livekit_http.arn
    container_name   = "livekit"
    container_port   = 7880
  }

  load_balancer {
    target_group_arn = aws_lb_target_group.livekit_turn_tcp.arn
    container_name   = "livekit"
    container_port   = 443
  }

  load_balancer {
    target_group_arn = aws_lb_target_group.livekit_turn_udp.arn
    container_name   = "livekit"
    container_port   = 443
  }

  tags = merge(var.tags, {
    Name = "${var.name_prefix}-livekit-service"
  })

  lifecycle {
    ignore_changes = [desired_count]
  }

  depends_on = [
    aws_lb_listener.livekit_https,
    aws_lb_listener.livekit_turn_tcp,
    aws_lb_listener.livekit_turn_udp
  ]
}

# CloudWatch Log Group
resource "aws_cloudwatch_log_group" "livekit" {
  name              = "/ecs/${var.name_prefix}/livekit"
  retention_in_days = var.log_retention_days

  tags = merge(var.tags, {
    Name = "${var.name_prefix}-livekit-logs"
  })
}

# Auto Scaling
resource "aws_appautoscaling_target" "livekit" {
  max_capacity       = var.livekit_max_capacity
  min_capacity       = var.livekit_min_capacity
  resource_id        = "service/${var.cluster_name}/${aws_ecs_service.livekit.name}"
  scalable_dimension = "ecs:service:DesiredCount"
  service_namespace  = "ecs"

  tags = var.tags
}

resource "aws_appautoscaling_policy" "livekit_cpu" {
  name               = "${var.name_prefix}-livekit-cpu-scaling"
  policy_type        = "TargetTrackingScaling"
  resource_id        = aws_appautoscaling_target.livekit.resource_id
  scalable_dimension = aws_appautoscaling_target.livekit.scalable_dimension
  service_namespace  = aws_appautoscaling_target.livekit.service_namespace

  target_tracking_scaling_policy_configuration {
    target_value = 60.0

    predefined_metric_specification {
      predefined_metric_type = "ECSServiceAverageCPUUtilization"
    }

    scale_out_cooldown = 180
    scale_in_cooldown  = 300
  }
}

resource "aws_appautoscaling_policy" "livekit_memory" {
  name               = "${var.name_prefix}-livekit-memory-scaling"
  policy_type        = "TargetTrackingScaling"
  resource_id        = aws_appautoscaling_target.livekit.resource_id
  scalable_dimension = aws_appautoscaling_target.livekit.scalable_dimension
  service_namespace  = aws_appautoscaling_target.livekit.service_namespace

  target_tracking_scaling_policy_configuration {
    target_value = 70.0

    predefined_metric_specification {
      predefined_metric_type = "ECSServiceAverageMemoryUtilization"
    }

    scale_out_cooldown = 180
    scale_in_cooldown  = 300
  }
}

# LiveKit Configuration
locals {
  livekit_config = yamlencode({
    port = 7880
    bind_addresses = ["0.0.0.0"]
    
    rtc = {
      tcp_port      = 7881
      port_range_start = 50000
      port_range_end   = 60000
      use_external_ip  = true
    }
    
    redis = {
      address  = "${var.redis_endpoint}:6379"
      username = ""
      password = ""
      db       = 0
    }
    
    turn = {
      enabled = true
      domain  = var.domain_name
      cert_file = "/etc/ssl/certs/cert.pem"
      key_file  = "/etc/ssl/private/key.pem"
      tls_port  = 443
      udp_port  = 443
    }
    
    webhook = {
      api_key = random_password.livekit_api_key.result
      urls    = ["https://api.${var.domain_name}/webhooks/livekit"]
    }
    
    room = {
      auto_create         = true
      enable_recording    = var.enable_recording
      enable_transcription = false
    }
    
    ingress = {
      rtmp_base_url = "rtmp://rtmp.${var.domain_name}/live"
      whip_base_url = "https://rtmp.${var.domain_name}/whip"
    }
    
    egress = {
      s3 = {
        access_key    = ""
        secret        = ""
        region        = var.aws_region
        bucket        = var.recordings_bucket_name
        force_path_style = false
      }
    }
  })
}