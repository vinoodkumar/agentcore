# Local variables
locals {
  name_prefix = "${var.name}-${var.environment}"

  common_tags = merge(
    {
      Name        = local.name_prefix
      Environment = var.environment
      ManagedBy   = "Terraform"
      Module      = "agentcore-gateway"
    },
    var.tags
  )
}

# KMS Key for encryption
resource "aws_kms_key" "this" {
  description             = var.kms_key_description
  deletion_window_in_days = var.kms_key_deletion_window
  enable_key_rotation     = true

  tags = merge(
    local.common_tags,
    {
      Name = "${local.name_prefix}-kms-key"
    }
  )
}

resource "aws_kms_alias" "this" {
  name          = "alias/${local.name_prefix}-agentcore"
  target_key_id = aws_kms_key.this.key_id
}

# CloudWatch Log Group
resource "aws_cloudwatch_log_group" "this" {
  name              = "/ecs/${local.name_prefix}-agentcore-gateway"
  retention_in_days = var.log_retention_days
  kms_key_id        = aws_kms_key.this.arn

  tags = merge(
    local.common_tags,
    {
      Name = "${local.name_prefix}-log-group"
    }
  )
}

# ECS Cluster
resource "aws_ecs_cluster" "this" {
  name = "${local.name_prefix}-agentcore-cluster"

  setting {
    name  = "containerInsights"
    value = var.enable_container_insights ? "enabled" : "disabled"
  }

  tags = merge(
    local.common_tags,
    {
      Name = "${local.name_prefix}-ecs-cluster"
    }
  )
}

# IAM Role for ECS Task Execution
resource "aws_iam_role" "ecs_task_execution_role" {
  name = "${local.name_prefix}-ecs-task-execution-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Principal = {
          Service = "ecs-tasks.amazonaws.com"
        }
        Action = "sts:AssumeRole"
      }
    ]
  })

  tags = merge(
    local.common_tags,
    {
      Name = "${local.name_prefix}-ecs-task-execution-role"
    }
  )
}

resource "aws_iam_role_policy_attachment" "ecs_task_execution_role_policy" {
  role       = aws_iam_role.ecs_task_execution_role.name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AmazonECSTaskExecutionRolePolicy"
}

# Additional policy for KMS and Secrets Manager access
resource "aws_iam_role_policy" "ecs_task_execution_additional" {
  name = "${local.name_prefix}-ecs-task-execution-additional"
  role = aws_iam_role.ecs_task_execution_role.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Action = [
          "kms:Decrypt",
          "kms:DescribeKey"
        ]
        Resource = aws_kms_key.this.arn
      },
      {
        Effect = "Allow"
        Action = [
          "secretsmanager:GetSecretValue"
        ]
        Resource = var.microsoft_oauth_secret_arn
      }
    ]
  })
}

# IAM Role for ECS Task
resource "aws_iam_role" "ecs_task_role" {
  name = "${local.name_prefix}-ecs-task-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Principal = {
          Service = "ecs-tasks.amazonaws.com"
        }
        Action = "sts:AssumeRole"
      }
    ]
  })

  tags = merge(
    local.common_tags,
    {
      Name = "${local.name_prefix}-ecs-task-role"
    }
  )
}

# IAM Policy for ECS Task Role (Least Privilege)
resource "aws_iam_role_policy" "ecs_task_role_policy" {
  name = "${local.name_prefix}-ecs-task-policy"
  role = aws_iam_role.ecs_task_role.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Action = [
          "logs:CreateLogGroup",
          "logs:CreateLogStream",
          "logs:PutLogEvents"
        ]
        Resource = "${aws_cloudwatch_log_group.this.arn}:*"
      },
      {
        Effect = "Allow"
        Action = [
          "kms:Decrypt",
          "kms:Encrypt",
          "kms:GenerateDataKey"
        ]
        Resource = aws_kms_key.this.arn
      },
      {
        Effect = "Allow"
        Action = [
          "secretsmanager:GetSecretValue"
        ]
        Resource = var.microsoft_oauth_secret_arn
      }
    ]
  })
}

# Optional: Workload Identity Role Assumption
resource "aws_iam_role_policy" "workload_identity" {
  count = var.workload_identity_role_arn != "" ? 1 : 0

  name = "${local.name_prefix}-workload-identity-policy"
  role = aws_iam_role.ecs_task_role.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Action = [
          "sts:AssumeRole"
        ]
        Resource = var.workload_identity_role_arn
      }
    ]
  })
}

# Security Group for ALB
resource "aws_security_group" "alb" {
  name        = "${local.name_prefix}-alb-sg"
  description = "Security group for AgentCore Gateway ALB"
  vpc_id      = var.vpc_id

  ingress {
    description = "HTTPS from allowed CIDR blocks"
    from_port   = 443
    to_port     = 443
    protocol    = "tcp"
    cidr_blocks = var.alb_ingress_cidr_blocks
  }

  egress {
    description = "Allow all outbound traffic"
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = merge(
    local.common_tags,
    {
      Name = "${local.name_prefix}-alb-sg"
    }
  )
}

# Security Group for ECS Service
resource "aws_security_group" "ecs_service" {
  name        = "${local.name_prefix}-ecs-service-sg"
  description = "Security group for AgentCore Gateway ECS Service"
  vpc_id      = var.vpc_id

  ingress {
    description     = "Traffic from ALB"
    from_port       = var.container_port
    to_port         = var.container_port
    protocol        = "tcp"
    security_groups = [aws_security_group.alb.id]
  }

  egress {
    description = "Allow all outbound traffic"
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = merge(
    local.common_tags,
    {
      Name = "${local.name_prefix}-ecs-service-sg"
    }
  )
}

# Application Load Balancer
resource "aws_lb" "this" {
  name               = "${local.name_prefix}-alb"
  internal           = false
  load_balancer_type = "application"
  security_groups    = [aws_security_group.alb.id]
  subnets            = var.public_subnet_ids

  enable_deletion_protection       = var.enable_deletion_protection
  enable_cross_zone_load_balancing = var.enable_cross_zone_load_balancing
  idle_timeout                     = var.idle_timeout

  tags = merge(
    local.common_tags,
    {
      Name = "${local.name_prefix}-alb"
    }
  )
}

# Target Group
resource "aws_lb_target_group" "this" {
  name                 = "${local.name_prefix}-tg"
  port                 = var.container_port
  protocol             = "HTTP"
  vpc_id               = var.vpc_id
  target_type          = "ip"
  deregistration_delay = var.deregistration_delay

  health_check {
    enabled             = true
    path                = var.health_check_path
    protocol            = "HTTP"
    interval            = var.health_check_interval
    timeout             = var.health_check_timeout
    healthy_threshold   = var.health_check_healthy_threshold
    unhealthy_threshold = var.health_check_unhealthy_threshold
    matcher             = var.health_check_matcher
  }

  tags = merge(
    local.common_tags,
    {
      Name = "${local.name_prefix}-target-group"
    }
  )
}

# HTTPS Listener
resource "aws_lb_listener" "https" {
  load_balancer_arn = aws_lb.this.arn
  port              = 443
  protocol          = "HTTPS"
  ssl_policy        = "ELBSecurityPolicy-TLS13-1-2-2021-06"
  certificate_arn   = var.certificate_arn

  default_action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.this.arn
  }

  tags = merge(
    local.common_tags,
    {
      Name = "${local.name_prefix}-https-listener"
    }
  )
}

# Optional: Host-based Routing
resource "aws_lb_listener_rule" "host_based" {
  count = length(var.host_based_routing_hosts) > 0 ? 1 : 0

  listener_arn = aws_lb_listener.https.arn
  priority     = 100

  action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.this.arn
  }

  condition {
    host_header {
      values = var.host_based_routing_hosts
    }
  }
}

# ECS Task Definition
resource "aws_ecs_task_definition" "this" {
  family                   = "${local.name_prefix}-agentcore-gateway"
  network_mode             = "awsvpc"
  requires_compatibilities = ["FARGATE"]
  cpu                      = var.cpu
  memory                   = var.memory
  execution_role_arn       = aws_iam_role.ecs_task_execution_role.arn
  task_role_arn            = aws_iam_role.ecs_task_role.arn

  container_definitions = jsonencode([
    {
      name  = "agentcore-gateway"
      image = var.container_image

      portMappings = [
        {
          containerPort = var.container_port
          protocol      = "tcp"
        }
      ]

      environment = concat(
        [
          {
            name  = "MICROSOFT_OAUTH_CLIENT_ID"
            value = var.microsoft_oauth_client_id
          },
          {
            name  = "MICROSOFT_OAUTH_TENANT_ID"
            value = var.microsoft_oauth_tenant_id
          },
          {
            name  = "PORT"
            value = tostring(var.container_port)
          },
          {
            name  = "ENVIRONMENT"
            value = var.environment
          }
        ],
        [
          for key, value in var.additional_container_environment_variables : {
            name  = key
            value = value
          }
        ]
      )

      secrets = [
        {
          name      = "MICROSOFT_OAUTH_CLIENT_SECRET"
          valueFrom = var.microsoft_oauth_secret_arn
        }
      ]

      logConfiguration = {
        logDriver = "awslogs"
        options = {
          "awslogs-group"         = aws_cloudwatch_log_group.this.name
          "awslogs-region"        = data.aws_region.current.id
          "awslogs-stream-prefix" = "ecs"
        }
      }

      healthCheck = {
        command     = ["CMD-SHELL", "curl -f http://localhost:${var.container_port}${var.health_check_path} || exit 1"]
        interval    = 30
        timeout     = 5
        retries     = 3
        startPeriod = 60
      }
    }
  ])

  tags = merge(
    local.common_tags,
    {
      Name = "${local.name_prefix}-task-definition"
    }
  )
}

# ECS Service
resource "aws_ecs_service" "this" {
  name            = "${local.name_prefix}-agentcore-service"
  cluster         = aws_ecs_cluster.this.id
  task_definition = aws_ecs_task_definition.this.arn
  desired_count   = var.desired_count
  launch_type     = "FARGATE"

  network_configuration {
    subnets          = var.private_subnet_ids
    security_groups  = [aws_security_group.ecs_service.id]
    assign_public_ip = false
  }

  load_balancer {
    target_group_arn = aws_lb_target_group.this.arn
    container_name   = "agentcore-gateway"
    container_port   = var.container_port
  }

  depends_on = [
    aws_lb_listener.https
  ]

  tags = merge(
    local.common_tags,
    {
      Name = "${local.name_prefix}-ecs-service"
    }
  )
}

# Auto Scaling Target
resource "aws_appautoscaling_target" "ecs" {
  count = var.enable_autoscaling ? 1 : 0

  max_capacity       = var.autoscaling_max_capacity
  min_capacity       = var.autoscaling_min_capacity
  resource_id        = "service/${aws_ecs_cluster.this.name}/${aws_ecs_service.this.name}"
  scalable_dimension = "ecs:service:DesiredCount"
  service_namespace  = "ecs"
}

# Auto Scaling Policy - CPU
resource "aws_appautoscaling_policy" "ecs_cpu" {
  count = var.enable_autoscaling ? 1 : 0

  name               = "${local.name_prefix}-cpu-autoscaling"
  policy_type        = "TargetTrackingScaling"
  resource_id        = aws_appautoscaling_target.ecs[0].resource_id
  scalable_dimension = aws_appautoscaling_target.ecs[0].scalable_dimension
  service_namespace  = aws_appautoscaling_target.ecs[0].service_namespace

  target_tracking_scaling_policy_configuration {
    predefined_metric_specification {
      predefined_metric_type = "ECSServiceAverageCPUUtilization"
    }
    target_value       = var.autoscaling_target_cpu
    scale_in_cooldown  = 300
    scale_out_cooldown = 60
  }
}

# Auto Scaling Policy - Memory
resource "aws_appautoscaling_policy" "ecs_memory" {
  count = var.enable_autoscaling ? 1 : 0

  name               = "${local.name_prefix}-memory-autoscaling"
  policy_type        = "TargetTrackingScaling"
  resource_id        = aws_appautoscaling_target.ecs[0].resource_id
  scalable_dimension = aws_appautoscaling_target.ecs[0].scalable_dimension
  service_namespace  = aws_appautoscaling_target.ecs[0].service_namespace

  target_tracking_scaling_policy_configuration {
    predefined_metric_specification {
      predefined_metric_type = "ECSServiceAverageMemoryUtilization"
    }
    target_value       = var.autoscaling_target_memory
    scale_in_cooldown  = 300
    scale_out_cooldown = 60
  }
}

# Data source for current region
data "aws_region" "current" {}
