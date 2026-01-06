variable "name_prefix" {
  type = string
}

variable "vpc_id" {
  type = string
}

variable "public_subnet_ids" {
  type = list(string)
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

variable "services" {
  type = map(object({
    name          = string
    port          = number
    cpu           = number
    memory        = number
    desired_count = number
    health_check  = string
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

variable "tags" {
  type    = map(string)
  default = {}
}
