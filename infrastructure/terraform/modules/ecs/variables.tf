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

variable "sqs_queue_url" {
  type = string
}

variable "tags" {
  type    = map(string)
  default = {}
}
