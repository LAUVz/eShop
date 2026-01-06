# ECS Cluster and Services

locals {
  # Build environment variables for each service
  service_env_vars = {
    webapp = [
      { name = "IdentityUrl", value = "http://${var.alb_dns_name}/identity" },
      { name = "CallBackUrl", value = "http://${var.alb_dns_name}" },
      { name = "ASPNETCORE_URLS", value = "http://+:8080" }
    ]
    unified-api = [
      { name = "ASPNETCORE_URLS", value = "http://+:8081" },
      { name = "ASPNETCORE_ENVIRONMENT", value = "Production" }
    ]
    payment-processor = [
      { name = "ASPNETCORE_URLS", value = "http://+:8082" },
      { name = "ASPNETCORE_ENVIRONMENT", value = "Production" }
    ]
    order-processor = [
      { name = "ASPNETCORE_URLS", value = "http://+:8083" },
      { name = "ASPNETCORE_ENVIRONMENT", value = "Production" }
    ]
  }
}

resource "aws_ecs_cluster" "main" {
  name = "${var.name_prefix}-cluster"
  tags = var.tags
}

resource "aws_ecs_cluster_capacity_providers" "main" {
  cluster_name = aws_ecs_cluster.main.name
  capacity_providers = ["FARGATE", "FARGATE_SPOT"]

  default_capacity_provider_strategy {
    capacity_provider = "FARGATE_SPOT"
    weight            = 1
  }
}

resource "aws_ecs_task_definition" "service" {
  for_each = var.services

  family                   = "${var.name_prefix}-${each.key}"
  network_mode             = "awsvpc"
  requires_compatibilities = ["FARGATE"]
  cpu                      = each.value.cpu
  memory                   = each.value.memory
  execution_role_arn       = aws_iam_role.ecs_execution.arn
  task_role_arn            = aws_iam_role.ecs_task.arn

  container_definitions = jsonencode([{
    name  = each.key
    image = "public.ecr.aws/docker/library/httpd:latest"  # Placeholder
    portMappings = [{
      containerPort = each.value.port
      protocol      = "tcp"
    }]
    environment = concat(
      [
        { name = "RDS_ENDPOINT", value = var.rds_endpoint },
        { name = "SQS_QUEUE_URL", value = var.sqs_queue_url }
      ],
      lookup(local.service_env_vars, each.key, [])
    )
    logConfiguration = {
      logDriver = "awslogs"
      options = {
        "awslogs-group"         = "/ecs/${var.name_prefix}"
        "awslogs-region"        = data.aws_region.current.name
        "awslogs-stream-prefix" = each.key
      }
    }
  }])

  tags = var.tags
}

resource "aws_ecs_service" "service" {
  for_each = var.services

  name            = each.key
  cluster         = aws_ecs_cluster.main.id
  task_definition = aws_ecs_task_definition.service[each.key].arn
  desired_count   = each.value.desired_count
  launch_type     = "FARGATE"

  network_configuration {
    subnets          = var.public_subnet_ids
    security_groups  = [var.ecs_security_group_id]
    assign_public_ip = true
  }

  # Only add load balancer for web services (use_alb = true)
  dynamic "load_balancer" {
    for_each = lookup(each.value, "use_alb", false) ? [1] : []
    content {
      target_group_arn = var.alb_target_group_arns[each.key]
      container_name   = each.key
      container_port   = each.value.port
    }
  }

  tags = var.tags
}

resource "aws_cloudwatch_log_group" "ecs" {
  name              = "/ecs/${var.name_prefix}"
  retention_in_days = 7
  tags              = var.tags
}

resource "aws_iam_role" "ecs_execution" {
  name = "${var.name_prefix}-ecs-execution"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Action = "sts:AssumeRole"
      Effect = "Allow"
      Principal = {
        Service = "ecs-tasks.amazonaws.com"
      }
    }]
  })

  tags = var.tags
}

resource "aws_iam_role_policy_attachment" "ecs_execution" {
  role       = aws_iam_role.ecs_execution.name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AmazonECSTaskExecutionRolePolicy"
}

resource "aws_iam_role" "ecs_task" {
  name = "${var.name_prefix}-ecs-task"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Action = "sts:AssumeRole"
      Effect = "Allow"
      Principal = {
        Service = "ecs-tasks.amazonaws.com"
      }
    }]
  })

  tags = var.tags
}

data "aws_region" "current" {}
