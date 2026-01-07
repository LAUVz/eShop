terraform {
  required_version = ">= 1.6.0"

  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
  }

  # Backend configuration for state management
  # Values provided via backend config file
  # Run: terraform init -backend-config=terraform-backend.tfvars

  backend "s3" {
  }
}

provider "aws" {
  region = var.aws_region

  default_tags {
    tags = {
      Project     = "eShop"
      ManagedBy   = "Terraform"
      Environment = var.environment
    }
  }
}

# Local variables
locals {
  name_prefix = "eshop-${var.environment}"

  common_tags = {
    Project     = "eShop"
    Environment = var.environment
    ManagedBy   = "Terraform"
  }

  # Web services (with load balancer)
  web_services = {
    webapp = {
      name          = "webapp"
      port          = 8080
      cpu           = 256
      memory        = 512
      desired_count = var.environment == "production" ? 2 : 1
      health_check  = "/health"
      use_alb       = true
    }
    unified-api = {
      name          = "unified-api"
      port          = 8081
      cpu           = 512
      memory        = 1024
      desired_count = var.environment == "production" ? 2 : 1
      health_check  = "/health"
      use_alb       = true
    }
  }

  # Infrastructure services (no load balancer)
  infrastructure_services = {
    rabbitmq = {
      name          = "rabbitmq"
      port          = 5672
      cpu           = 256
      memory        = 512
      desired_count = 1
      health_check  = "/health"
      use_alb       = false
    }
  }

  # Worker services (background processors, no load balancer)
  worker_services = {
    payment-processor = {
      name          = "payment-processor"
      port          = 8082
      cpu           = 256
      memory        = 512
      desired_count = 1
      health_check  = "/health"
      use_alb       = false
    }
    order-processor = {
      name          = "order-processor"
      port          = 8083
      cpu           = 256
      memory        = 512
      desired_count = 1
      health_check  = "/health"
      use_alb       = false
    }
  }

  # All services combined
  services = merge(local.web_services, local.infrastructure_services, local.worker_services)

  # All services for ECR repositories
  all_services = keys(local.services)
}

# Modules

# VPC and Networking
module "vpc" {
  source = "./modules/vpc"

  name_prefix         = local.name_prefix
  vpc_cidr            = var.vpc_cidr
  availability_zones  = var.availability_zones
  enable_nat_gateway  = true
  single_nat_gateway  = var.environment != "production" # Cost optimization for dev/staging
  enable_vpn_gateway  = false

  tags = local.common_tags
}

# Security Groups
module "security_groups" {
  source = "./modules/security_groups"

  name_prefix = local.name_prefix
  vpc_id      = module.vpc.vpc_id
  vpc_cidr    = var.vpc_cidr

  tags = local.common_tags
}

# Application Load Balancer
module "alb" {
  source = "./modules/alb"

  name_prefix         = local.name_prefix
  vpc_id              = module.vpc.vpc_id
  public_subnet_ids   = module.vpc.public_subnet_ids
  security_group_ids  = [module.security_groups.alb_security_group_id]
  certificate_arn     = "arn:aws:acm:eu-west-3:894426806671:certificate/4286ab2b-5f14-44ed-a75a-ed0ee2dd5853"

  tags = local.common_tags
}

# ECR Repositories
module "ecr" {
  source = "./modules/ecr"

  name_prefix = local.name_prefix
  services    = local.all_services  # Include both ECS and Lambda services

  tags = local.common_tags
}

# ECS Cluster and Services
module "ecs" {
  source = "./modules/ecs"

  name_prefix            = local.name_prefix
  vpc_id                 = module.vpc.vpc_id
  public_subnet_ids      = module.vpc.public_subnet_ids  # COST-OPTIMIZATION: Public subnets (no NAT Gateway)
  ecs_security_group_id  = module.security_groups.ecs_security_group_id
  alb_target_group_arns  = module.alb.target_group_arns
  alb_dns_name           = module.alb.alb_dns_name
  services               = local.services

  # Dependencies
  rds_endpoint           = module.rds.endpoint
  rds_password           = var.rds_master_password
  sqs_queue_url          = module.sqs.queue_url  # COST-OPTIMIZATION: SQS instead of RabbitMQ

  tags = local.common_tags
}

# RDS PostgreSQL Databases
module "rds" {
  source = "./modules/rds"

  name_prefix           = local.name_prefix
  vpc_id                = module.vpc.vpc_id
  private_subnet_ids    = module.vpc.private_data_subnet_ids
  security_group_ids    = [module.security_groups.rds_security_group_id]

  # Instance configuration
  instance_class        = var.environment == "production" ? "db.t4g.small" : "db.t4g.micro"
  multi_az              = var.environment == "production"
  allocated_storage     = 20
  max_allocated_storage = 100

  # Credentials
  rds_master_password   = var.rds_master_password

  # Databases to create
  databases = [
    "eshop_identity",
    "eshop_catalog",
    "eshop_ordering",
    "eshop_webhooks"
  ]

  # Backup configuration
  backup_retention_period = var.environment == "production" ? 7 : 3
  backup_window          = "03:00-04:00"
  maintenance_window     = "sun:04:00-sun:05:00"

  tags = local.common_tags
}

# Amazon SQS for event messaging
module "sqs" {
  source = "./modules/sqs"

  name_prefix = local.name_prefix

  # Queue configuration
  visibility_timeout_seconds = 300
  message_retention_seconds  = 345600  # 4 days
  max_message_size          = 262144   # 256 KB
  delay_seconds             = 0
  receive_wait_time_seconds = 0

  # Dead letter queue
  enable_dlq              = true
  max_receive_count       = 3

  tags = local.common_tags
}

# Lambda functions removed - applications not designed for Lambda runtime
# Keeping configuration commented for reference
# module "lambda" {
#   source = "./modules/lambda"
#
#   name_prefix = local.name_prefix
#
#   # Functions configuration
#   functions = {
#     for name, config in local.lambda_functions : name => {
#       memory_size = config.memory_size
#       timeout     = config.timeout
#       environment = merge(config.environment, {
#         SQS_QUEUE_URL = module.sqs.queue_url
#         RDS_ENDPOINT  = module.rds.endpoint
#       })
#     }
#   }
#
#   # ECR repository URLs for container images
#   ecr_repository_urls = {
#     for name in keys(local.lambda_functions) : name => module.ecr.repository_urls[name]
#   }
#
#   # SQS trigger
#   sqs_queue_arn = module.sqs.queue_arn
#
#   tags = local.common_tags
# }

# Secrets Manager
module "secrets" {
  source = "./modules/secrets"

  name_prefix = local.name_prefix

  # RDS credentials
  rds_master_password = var.rds_master_password

  # RabbitMQ credentials
  rabbitmq_username = var.rabbitmq_username
  rabbitmq_password = var.rabbitmq_password

  # JWT secret
  jwt_secret_key = var.jwt_secret_key

  tags = local.common_tags
}

# CloudWatch Monitoring
module "monitoring" {
  source = "./modules/monitoring"

  project_name       = "eShop"
  environment        = var.environment
  aws_region         = var.aws_region
  sns_email_endpoint = var.alert_email
  common_tags        = local.common_tags
}

# Auto Scaling
module "autoscaling" {
  source = "./modules/autoscaling"

  name_prefix       = local.name_prefix
  ecs_cluster_name  = module.ecs.cluster_name
  services          = local.services
  ecs_service_names = module.ecs.service_ids

  # Scaling configuration
  min_capacity = var.environment == "production" ? 2 : 1
  max_capacity = var.environment == "production" ? 20 : 5

  tags = local.common_tags
}

# Outputs
output "vpc_id" {
  description = "VPC ID"
  value       = module.vpc.vpc_id
}

output "alb_dns_name" {
  description = "ALB DNS name"
  value       = module.alb.alb_dns_name
}

output "alb_url" {
  description = "ALB URL"
  value       = "http://${module.alb.alb_dns_name}"
}

output "ecr_repository_urls" {
  description = "ECR repository URLs"
  value       = module.ecr.repository_urls
}

output "ecs_cluster_name" {
  description = "ECS cluster name"
  value       = module.ecs.cluster_name
}

output "rds_endpoint" {
  description = "RDS endpoint"
  value       = module.rds.endpoint
  sensitive   = true
}

output "sqs_queue_url" {
  description = "SQS queue URL"
  value       = module.sqs.queue_url
}

# Lambda output commented out - module removed
# output "lambda_function_arns" {
#   description = "Lambda function ARNs"
#   value       = module.lambda.function_arns
# }

output "monitoring_dashboard_url" {
  description = "CloudWatch dashboard URL"
  value       = module.monitoring.dashboard_url
}
