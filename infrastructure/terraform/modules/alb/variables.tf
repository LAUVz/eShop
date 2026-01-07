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

variable "tags" {
  type    = map(string)
  default = {}
}
