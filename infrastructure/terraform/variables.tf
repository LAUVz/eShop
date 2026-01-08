# eShop Terraform Variables

variable "aws_region" {
  description = "AWS region to deploy resources"
  type        = string
  default     = "us-east-1"
}

variable "environment" {
  description = "Environment name (dev, staging, production)"
  type        = string

  validation {
    condition     = contains(["dev", "staging", "production"], var.environment)
    error_message = "Environment must be dev, staging, or production."
  }
}

variable "vpc_cidr" {
  description = "CIDR block for VPC"
  type        = string
  default     = "10.0.0.0/16"
}

variable "availability_zones" {
  description = "Availability zones to use"
  type        = list(string)
  default     = ["us-east-1a", "us-east-1b"]
}

variable "app_url" {
  description = "Public HTTPS URL for the application (e.g., https://eshop.example.com)"
  type        = string
  default     = ""
}

# Database Variables
variable "rds_master_password" {
  description = "Master password for RDS PostgreSQL"
  type        = string
  sensitive   = true
}

# RabbitMQ Variables
variable "rabbitmq_username" {
  description = "RabbitMQ admin username"
  type        = string
  default     = "eshop_admin"
}

variable "rabbitmq_password" {
  description = "RabbitMQ admin password"
  type        = string
  sensitive   = true
}

# Security Variables
variable "jwt_secret_key" {
  description = "JWT secret key for token signing"
  type        = string
  sensitive   = true
}

# Monitoring Variables
variable "alert_email" {
  description = "Email address for CloudWatch alerts"
  type        = string
}

# Cost Optimization Variables
variable "enable_cost_optimization" {
  description = "Enable cost optimization features (single NAT, smaller instances)"
  type        = bool
  default     = true
}

variable "use_single_nat_gateway" {
  description = "Use single NAT gateway instead of one per AZ (cost optimization)"
  type        = bool
  default     = true
}
