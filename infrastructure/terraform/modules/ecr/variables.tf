variable "name_prefix" {
  description = "Prefix for repository names"
  type        = string
}

variable "services" {
  description = "List of service names to create repositories for"
  type        = list(string)
}

variable "tags" {
  description = "Tags to apply to repositories"
  type        = map(string)
  default     = {}
}
