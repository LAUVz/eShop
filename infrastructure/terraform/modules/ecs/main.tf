# ECS Cluster and Services

locals {
  # Parse RDS endpoint to get host and port
  rds_parts = split(":", var.rds_endpoint)
  rds_host  = local.rds_parts[0]
  rds_port  = local.rds_parts[1]

  # RabbitMQ connection string (using service discovery via task networking)
  # RabbitMQ will be accessible at rabbitmq.local within the VPC
  rabbitmq_host = "rabbitmq.${var.name_prefix}.local"
  eventbus_connection = "amqp://guest:guest@${local.rabbitmq_host}:5672"

  # Build environment variables for each service
  service_env_vars = {
    webapp = [
      { name = "IdentityUrl", value = "http://${var.alb_dns_name}/identity" },
      { name = "CallBackUrl", value = "http://${var.alb_dns_name}" },
      { name = "ASPNETCORE_URLS", value = "http://+:8080" },
      { name = "ConnectionStrings__EventBus", value = local.eventbus_connection },
      # Override service discovery to point to ALB paths
      { name = "services__catalog-api__http__0", value = "http://${var.alb_dns_name}" },
      { name = "services__catalog-api__https__0", value = "http://${var.alb_dns_name}" },
      { name = "services__basket-api__http__0", value = "http://${var.alb_dns_name}" },
      { name = "services__ordering-api__http__0", value = "http://${var.alb_dns_name}" }
    ]
    unified-api = [
      { name = "RDS_HOST", value = local.rds_host },
      { name = "RDS_PORT", value = local.rds_port },
      { name = "RDS_PASSWORD", value = var.rds_password },
      { name = "ConnectionStrings__EventBus", value = local.eventbus_connection }
    ]
    rabbitmq = []
    payment-processor = [
      { name = "ConnectionStrings__EventBus", value = local.eventbus_connection }
    ]
    order-processor = [
      { name = "ConnectionStrings__EventBus", value = local.eventbus_connection }
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
    image = "public.ecr.aws/docker/library/httpd:latest"  # Placeholder - updated by CI/CD
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

  # Enable service discovery for RabbitMQ
  dynamic "service_registries" {
    for_each = each.key == "rabbitmq" ? [1] : []
    content {
      registry_arn = aws_service_discovery_service.rabbitmq[0].arn
    }
  }

  # Ignore changes to task_definition - it's updated by CI/CD pipeline
  # but preserve load balancer config which is immutable
  lifecycle {
    ignore_changes = [task_definition, desired_count]
  }

  tags = var.tags
}

# Service Discovery namespace for internal service communication
resource "aws_service_discovery_private_dns_namespace" "main" {
  name        = "${var.name_prefix}.local"
  vpc         = var.vpc_id
  description = "Service discovery namespace for ${var.name_prefix}"

  tags = var.tags
}

# Service Discovery service for RabbitMQ
resource "aws_service_discovery_service" "rabbitmq" {
  count = contains(keys(var.services), "rabbitmq") ? 1 : 0

  name = "rabbitmq"

  dns_config {
    namespace_id = aws_service_discovery_private_dns_namespace.main.id

    dns_records {
      ttl  = 10
      type = "A"
    }

    routing_policy = "MULTIVALUE"
  }

  health_check_custom_config {
    failure_threshold = 1
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
