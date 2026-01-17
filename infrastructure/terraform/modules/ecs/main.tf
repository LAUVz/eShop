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

  # Use custom app URL if provided, otherwise use ALB DNS name
  base_url = var.app_url != "" ? var.app_url : "http://${var.alb_dns_name}"

  # Identity Server URL - NO /identity prefix needed! ALB routes to it directly
  identity_url = local.base_url

  # Build environment variables for each service (matching .NET Aspire AppHost configuration)
  service_env_vars = {
    # WebApp - main UI
    webapp = [
      { name = "IdentityUrl", value = local.identity_url },
      { name = "CallBackUrl", value = local.base_url },
      { name = "ASPNETCORE_URLS", value = "http://+:8080" },
      { name = "ConnectionStrings__EventBus", value = local.eventbus_connection },
      # API endpoints - all via ALB
      { name = "services__catalog-api__http__0", value = local.base_url },
      { name = "services__catalog-api__https__0", value = local.base_url },
      { name = "services__basket-api__http__0", value = local.base_url },
      { name = "services__ordering-api__http__0", value = local.base_url }
    ]

    # Identity API - authentication & authorization
    identity-api = [
      { name = "ASPNETCORE_URLS", value = "http://+:8081" },
      { name = "ASPNETCORE_FORWARDEDHEADERS_ENABLED", value = "true" },
      { name = "RDS_HOST", value = local.rds_host },
      { name = "RDS_PORT", value = local.rds_port },
      { name = "RDS_PASSWORD", value = var.rds_password },
      { name = "ConnectionStrings__IdentityDB", value = "Host=${local.rds_host};Port=${local.rds_port};Database=eshop_identity;Username=eshop_admin;Password=${var.rds_password}" },
      { name = "IdentityServer__IssuerUri", value = local.identity_url },
      # Client callback URLs
      { name = "BasketApiClient", value = "${local.base_url}" },
      { name = "OrderingApiClient", value = "${local.base_url}" },
      { name = "WebhooksApiClient", value = "${local.base_url}" },
      { name = "WebAppClient", value = local.base_url }
    ]

    # Catalog API - product catalog
    catalog-api = [
      { name = "ASPNETCORE_URLS", value = "http://+:8082" },
      { name = "RDS_HOST", value = local.rds_host },
      { name = "RDS_PORT", value = local.rds_port },
      { name = "RDS_PASSWORD", value = var.rds_password },
      { name = "ConnectionStrings__CatalogDB", value = "Host=${local.rds_host};Port=${local.rds_port};Database=eshop_catalog;Username=eshop_admin;Password=${var.rds_password}" },
      { name = "ConnectionStrings__EventBus", value = local.eventbus_connection }
    ]

    # Basket API - shopping cart
    basket-api = [
      { name = "ASPNETCORE_URLS", value = "http://+:8083" },
      { name = "ConnectionStrings__EventBus", value = local.eventbus_connection },
      { name = "Identity__Url", value = local.identity_url }
    ]

    # Ordering API - order management
    ordering-api = [
      { name = "ASPNETCORE_URLS", value = "http://+:8084" },
      { name = "RDS_HOST", value = local.rds_host },
      { name = "RDS_PORT", value = local.rds_port },
      { name = "RDS_PASSWORD", value = var.rds_password },
      { name = "ConnectionStrings__OrderingDB", value = "Host=${local.rds_host};Port=${local.rds_port};Database=eshop_ordering;Username=eshop_admin;Password=${var.rds_password}" },
      { name = "ConnectionStrings__EventBus", value = local.eventbus_connection },
      { name = "Identity__Url", value = local.identity_url }
    ]

    # Webhooks API - webhook management
    webhooks-api = [
      { name = "ASPNETCORE_URLS", value = "http://+:8085" },
      { name = "RDS_HOST", value = local.rds_host },
      { name = "RDS_PORT", value = local.rds_port },
      { name = "RDS_PASSWORD", value = var.rds_password },
      { name = "ConnectionStrings__WebhooksDB", value = "Host=${local.rds_host};Port=${local.rds_port};Database=eshop_webhooks;Username=eshop_admin;Password=${var.rds_password}" },
      { name = "ConnectionStrings__EventBus", value = local.eventbus_connection },
      { name = "Identity__Url", value = local.identity_url }
    ]

    # Worker services
    payment-processor = [
      { name = "ASPNETCORE_URLS", value = "http://+:8086" },
      { name = "ConnectionStrings__EventBus", value = local.eventbus_connection }
    ]
    order-processor = [
      { name = "ASPNETCORE_URLS", value = "http://+:8087" },
      { name = "RDS_HOST", value = local.rds_host },
      { name = "RDS_PORT", value = local.rds_port },
      { name = "RDS_PASSWORD", value = var.rds_password },
      { name = "ConnectionStrings__OrderingDB", value = "Host=${local.rds_host};Port=${local.rds_port};Database=eshop_ordering;Username=eshop_admin;Password=${var.rds_password}" },
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
    subnets          = var.private_app_subnet_ids
    security_groups  = [var.ecs_security_group_id]
    assign_public_ip = false
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

  # Enable Service Connect for webapp and unified-api
  # TEMPORARILY DISABLED - requires CI/CD pipeline to create task definitions with named ports
  # dynamic "service_connect_configuration" {
  #   for_each = contains(["webapp", "unified-api"], each.key) ? [1] : []
  #   content {
  #     enabled = true
  #
  #     # unified-api registers as a service that others can discover
  #     dynamic "service" {
  #       for_each = each.key == "unified-api" ? [1] : []
  #       content {
  #         port_name      = "app"
  #         discovery_name = "unified-api"
  #
  #         client_alias {
  #           port     = each.value.port
  #           dns_name = "unified-api"
  #         }
  #       }
  #     }
  #   }
  # }

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
