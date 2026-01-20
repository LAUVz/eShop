variable "name_prefix" {
  type = string
}

variable "vpc_id" {
  type = string
}

variable "public_subnet_ids" {
  type        = list(string)
  description = "Public subnet IDs for ECS tasks (no NAT Gateway needed)"
}

variable "ecs_security_group_id" {
  type = string
}

variable "alb_target_group_arns" {
  type = map(string)
}

variable "alb_dns_name" {
  type        = string
  description = "ALB DNS name for service-to-service communication"
}

variable "app_url" {
  type        = string
  description = "Public URL for the application (with https://)"
  default     = ""
}

variable "services" {
  type = map(object({
    name          = string
    port          = number
    cpu           = number
    memory        = number
    desired_count = number
    health_check  = string
    use_alb       = optional(bool, false)
  }))
}

variable "rds_endpoint" {
  type = string
}

variable "rds_password" {
  type        = string
  description = "RDS master password for database connections"
  sensitive   = true
}

variable "sqs_queue_url" {
  type = string
}

variable "use_multi_container_task" {
  type        = bool
  description = "Use single multi-container task instead of separate tasks per service (like docker-compose)"
  default     = true
}

variable "task_cpu" {
  type        = string
  description = "Total CPU for multi-container task (1024 = 1 vCPU, 2048 = 2 vCPU)"
  default     = "1024"
}

variable "task_memory" {
  type        = string
  description = "Total memory for multi-container task in MB"
  default     = "2048"
}

variable "tags" {
  type    = map(string)
  default = {}
}
