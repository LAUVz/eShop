# COST-OPTIMIZED ECS Module - Single Multi-Container Task
# This runs all services in ONE ECS task (like docker-compose)
# Saves ~$20/month on compute costs

locals {
  # Parse RDS endpoint to get host and port
  rds_parts = split(":", var.rds_endpoint)
  rds_host  = local.rds_parts[0]
  rds_port  = local.rds_parts[1]

  # SQS for event bus (replacing RabbitMQ for cost optimization)
  eventbus_connection = var.sqs_queue_url

  # Use custom app URL if provided, otherwise use ALB DNS name
  base_url = var.app_url != "" ? var.app_url : "http://${var.alb_dns_name}"

  # Identity Server URL
  identity_url = local.base_url

  # Build container definitions for multi-container task
  # All containers run in the same task, can communicate via localhost
  container_definitions = [
    # WebApp - main UI (port 8080)
    {
      name   = "webapp"
      image  = "public.ecr.aws/docker/library/httpd:latest"  # Placeholder
      cpu    = 256  # 0.25 vCPU
      memory = 512  # 512 MB
      portMappings = [{
        containerPort = 8080
        hostPort      = 8080
        protocol      = "tcp"
      }]
      environment = [
        { name = "ASPNETCORE_URLS", value = "http://+:8080" },
        { name = "IdentityUrl", value = "http://localhost:8081" },  # Via localhost!
        { name = "CallBackUrl", value = local.base_url },
        { name = "services__catalog-api__http__0", value = "http://localhost:8082" },
        { name = "services__basket-api__http__0", value = "http://localhost:8083" },
        { name = "services__ordering-api__http__0", value = "http://localhost:8084" },
        { name = "SQS_QUEUE_URL", value = var.sqs_queue_url }
      ]
      logConfiguration = {
        logDriver = "awslogs"
        options = {
          "awslogs-group"         = aws_cloudwatch_log_group.ecs.name
          "awslogs-region"        = data.aws_region.current.name
          "awslogs-stream-prefix" = "webapp"
        }
      }
      essential = true
    },

    # Identity API - authentication (port 8081)
    {
      name   = "identity-api"
      image  = "public.ecr.aws/docker/library/httpd:latest"
      cpu    = 256  # 0.25 vCPU
      memory = 512  # 512 MB
      portMappings = [{
        containerPort = 8081
        hostPort      = 8081
        protocol      = "tcp"
      }]
      environment = [
        { name = "ASPNETCORE_URLS", value = "http://+:8081" },
        { name = "ASPNETCORE_FORWARDEDHEADERS_ENABLED", value = "true" },
        { name = "ConnectionStrings__IdentityDB", value = "Host=${local.rds_host};Port=${local.rds_port};Database=eshop_identity;Username=eshop_admin;Password=${var.rds_password}" },
        { name = "IdentityServer__IssuerUri", value = local.identity_url },
        { name = "BasketApiClient", value = local.base_url },
        { name = "OrderingApiClient", value = local.base_url },
        { name = "WebhooksApiClient", value = local.base_url },
        { name = "WebAppClient", value = local.base_url }
      ]
      logConfiguration = {
        logDriver = "awslogs"
        options = {
          "awslogs-group"         = aws_cloudwatch_log_group.ecs.name
          "awslogs-region"        = data.aws_region.current.name
          "awslogs-stream-prefix" = "identity-api"
        }
      }
      essential = true
    },

    # Catalog API - product catalog (port 8082)
    {
      name   = "catalog-api"
      image  = "public.ecr.aws/docker/library/httpd:latest"
      cpu    = 256  # 0.25 vCPU
      memory = 512  # 512 MB
      portMappings = [{
        containerPort = 8082
        hostPort      = 8082
        protocol      = "tcp"
      }]
      environment = [
        { name = "ASPNETCORE_URLS", value = "http://+:8082" },
        { name = "ConnectionStrings__CatalogDB", value = "Host=${local.rds_host};Port=${local.rds_port};Database=eshop_catalog;Username=eshop_admin;Password=${var.rds_password}" },
        { name = "SQS_QUEUE_URL", value = var.sqs_queue_url }
      ]
      logConfiguration = {
        logDriver = "awslogs"
        options = {
          "awslogs-group"         = aws_cloudwatch_log_group.ecs.name
          "awslogs-region"        = data.aws_region.current.name
          "awslogs-stream-prefix" = "catalog-api"
        }
      }
      essential = false  # Non-essential so task doesn't stop if this fails
    },

    # Basket API - shopping cart (port 8083)
    {
      name   = "basket-api"
      image  = "public.ecr.aws/docker/library/httpd:latest"
      cpu    = 256  # 0.25 vCPU
      memory = 512  # 512 MB
      portMappings = [{
        containerPort = 8083
        hostPort      = 8083
        protocol      = "tcp"
      }]
      environment = [
        { name = "ASPNETCORE_URLS", value = "http://+:8083" },
        { name = "Identity__Url", value = "http://localhost:8081" },
        { name = "SQS_QUEUE_URL", value = var.sqs_queue_url }
      ]
      logConfiguration = {
        logDriver = "awslogs"
        options = {
          "awslogs-group"         = aws_cloudwatch_log_group.ecs.name
          "awslogs-region"        = data.aws_region.current.name
          "awslogs-stream-prefix" = "basket-api"
        }
      }
      essential = false
    },

    # Ordering API - order management (port 8084)
    {
      name   = "ordering-api"
      image  = "public.ecr.aws/docker/library/httpd:latest"
      cpu    = 256  # 0.25 vCPU
      memory = 512  # 512 MB
      portMappings = [{
        containerPort = 8084
        hostPort      = 8084
        protocol      = "tcp"
      }]
      environment = [
        { name = "ASPNETCORE_URLS", value = "http://+:8084" },
        { name = "ConnectionStrings__OrderingDB", value = "Host=${local.rds_host};Port=${local.rds_port};Database=eshop_ordering;Username=eshop_admin;Password=${var.rds_password}" },
        { name = "Identity__Url", value = "http://localhost:8081" },
        { name = "SQS_QUEUE_URL", value = var.sqs_queue_url }
      ]
      logConfiguration = {
        logDriver = "awslogs"
        options = {
          "awslogs-group"         = aws_cloudwatch_log_group.ecs.name
          "awslogs-region"        = data.aws_region.current.name
          "awslogs-stream-prefix" = "ordering-api"
        }
      }
      essential = false
    },

    # Webhooks API - webhook management (port 8085)
    {
      name   = "webhooks-api"
      image  = "public.ecr.aws/docker/library/httpd:latest"
      cpu    = 128  # 0.125 vCPU (smaller, not web-facing)
      memory = 256  # 256 MB
      portMappings = [{
        containerPort = 8085
        hostPort      = 8085
        protocol      = "tcp"
      }]
      environment = [
        { name = "ASPNETCORE_URLS", value = "http://+:8085" },
        { name = "ConnectionStrings__WebhooksDB", value = "Host=${local.rds_host};Port=${local.rds_port};Database=eshop_webhooks;Username=eshop_admin;Password=${var.rds_password}" },
        { name = "Identity__Url", value = "http://localhost:8081" },
        { name = "SQS_QUEUE_URL", value = var.sqs_queue_url }
      ]
      logConfiguration = {
        logDriver = "awslogs"
        options = {
          "awslogs-group"         = aws_cloudwatch_log_group.ecs.name
          "awslogs-region"        = data.aws_region.current.name
          "awslogs-stream-prefix" = "webhooks-api"
        }
      }
      essential = false
    },

    # Payment Processor - background worker (port 8086)
    {
      name   = "payment-processor"
      image  = "public.ecr.aws/docker/library/httpd:latest"
      cpu    = 128  # 0.125 vCPU (background worker)
      memory = 256  # 256 MB
      portMappings = [{
        containerPort = 8086
        hostPort      = 8086
        protocol      = "tcp"
      }]
      environment = [
        { name = "ASPNETCORE_URLS", value = "http://+:8086" },
        { name = "SQS_QUEUE_URL", value = var.sqs_queue_url }
      ]
      logConfiguration = {
        logDriver = "awslogs"
        options = {
          "awslogs-group"         = aws_cloudwatch_log_group.ecs.name
          "awslogs-region"        = data.aws_region.current.name
          "awslogs-stream-prefix" = "payment-processor"
        }
      }
      essential = false
    },

    # Order Processor - background worker (port 8087)
    {
      name   = "order-processor"
      image  = "public.ecr.aws/docker/library/httpd:latest"
      cpu    = 128  # 0.125 vCPU (background worker)
      memory = 256  # 256 MB
      portMappings = [{
        containerPort = 8087
        hostPort      = 8087
        protocol      = "tcp"
      }]
      environment = [
        { name = "ASPNETCORE_URLS", value = "http://+:8087" },
        { name = "ConnectionStrings__OrderingDB", value = "Host=${local.rds_host};Port=${local.rds_port};Database=eshop_ordering;Username=eshop_admin;Password=${var.rds_password}" },
        { name = "SQS_QUEUE_URL", value = var.sqs_queue_url }
      ]
      logConfiguration = {
        logDriver = "awslogs"
        options = {
          "awslogs-group"         = aws_cloudwatch_log_group.ecs.name
          "awslogs-region"        = data.aws_region.current.name
          "awslogs-stream-prefix" = "order-processor"
        }
      }
      essential = false
    }
  ]
}

# ECS Cluster
resource "aws_ecs_cluster" "main" {
  name = "${var.name_prefix}-cluster"
  tags = var.tags
}

# Use FARGATE_SPOT for cost savings (70% cheaper)
resource "aws_ecs_cluster_capacity_providers" "main" {
  cluster_name       = aws_ecs_cluster.main.name
  capacity_providers = ["FARGATE", "FARGATE_SPOT"]

  default_capacity_provider_strategy {
    capacity_provider = "FARGATE_SPOT"
    weight            = 1
  }
}

# CloudWatch Log Group
resource "aws_cloudwatch_log_group" "ecs" {
  name              = "/ecs/${var.name_prefix}"
  retention_in_days = 7
  tags              = var.tags
}

# Multi-Container Task Definition
resource "aws_ecs_task_definition" "app" {
  family                   = "${var.name_prefix}-app"
  network_mode             = "awsvpc"
  requires_compatibilities = ["FARGATE"]
  cpu                      = var.task_cpu     # 1024 = 1 vCPU
  memory                   = var.task_memory  # 2048 = 2GB
  execution_role_arn       = aws_iam_role.ecs_execution.arn
  task_role_arn            = aws_iam_role.ecs_task.arn

  container_definitions = jsonencode(local.container_definitions)

  tags = var.tags
}

# Single ECS Service running the multi-container task
resource "aws_ecs_service" "app" {
  name            = "${var.name_prefix}-app"
  cluster         = aws_ecs_cluster.main.id
  task_definition = aws_ecs_task_definition.app.arn
  desired_count   = 1  # Start with 1, can scale up
  launch_type     = "FARGATE"

  network_configuration {
    subnets          = var.public_subnet_ids  # Public subnets, no NAT Gateway needed!
    security_groups  = [var.ecs_security_group_id]
    assign_public_ip = true  # Give task a public IP to access ECR/internet
  }

  # ECS Service Load Balancer Limit: Maximum 5 per service
  # Register the 5 most critical web-facing services:
  # 1. webapp - main UI
  # 2. identity-api - CRITICAL for auth/login (OAuth redirects need direct access)
  # 3. catalog-api - product browsing
  # 4. basket-api - shopping cart
  # 5. ordering-api - order placement
  # Note: webhooks-api (port 8085) not registered - it's internal/admin only
  # payment-processor and order-processor are background workers (no web access needed)

  load_balancer {
    target_group_arn = var.alb_target_group_arns["webapp"]
    container_name   = "webapp"
    container_port   = 8080
  }

  load_balancer {
    target_group_arn = var.alb_target_group_arns["identity-api"]
    container_name   = "identity-api"
    container_port   = 8081
  }

  load_balancer {
    target_group_arn = var.alb_target_group_arns["catalog-api"]
    container_name   = "catalog-api"
    container_port   = 8082
  }

  load_balancer {
    target_group_arn = var.alb_target_group_arns["basket-api"]
    container_name   = "basket-api"
    container_port   = 8083
  }

  load_balancer {
    target_group_arn = var.alb_target_group_arns["ordering-api"]
    container_name   = "ordering-api"
    container_port   = 8084
  }

  # Ignore task_definition changes (updated by CI/CD)
  lifecycle {
    ignore_changes = [task_definition, desired_count]
  }

  tags = var.tags
}

# IAM Roles
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

# Grant task permission to access SQS
resource "aws_iam_role_policy" "ecs_task_sqs" {
  name = "${var.name_prefix}-ecs-task-sqs"
  role = aws_iam_role.ecs_task.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Action = [
          "sqs:SendMessage",
          "sqs:ReceiveMessage",
          "sqs:DeleteMessage",
          "sqs:GetQueueAttributes"
        ]
        Resource = "*"
      }
    ]
  })
}

data "aws_region" "current" {}
