variable "name_prefix" {
  type = string
}

variable "vpc_id" {
  type = string
}

variable "public_subnet_ids" {
  type = list(string)
}

variable "security_group_ids" {
  type = list(string)
}

variable "certificate_arn" {
  type        = string
  description = "ARN of the ACM certificate for HTTPS"
}

variable "services" {
  type = map(object({
    name          = string
    port          = number
    cpu           = number
    memory        = number
    desired_count = number
    health_check  = string
    use_alb       = bool
  }))
  description = "Map of services that use the ALB"
}

variable "tags" {
  type    = map(string)
  default = {}
}
