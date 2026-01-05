variable "name_prefix" {
  type = string
}

variable "ecs_cluster_name" {
  type = string
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

variable "min_capacity" {
  type    = number
  default = 1
}

variable "max_capacity" {
  type    = number
  default = 5
}

variable "tags" {
  type    = map(string)
  default = {}
}
