variable "name_prefix" {
  description = "Prefix for resource names"
  type        = string
}

variable "functions" {
  description = "Map of Lambda functions to create"
  type = map(object({
    memory_size = number
    timeout     = number
    environment = map(string)
  }))
}

variable "ecr_repository_urls" {
  description = "Map of ECR repository URLs for container images"
  type        = map(string)
  default     = {}
}

variable "sqs_queue_arn" {
  description = "SQS queue ARN for event source"
  type        = string
}

variable "tags" {
  description = "Tags to apply to resources"
  type        = map(string)
  default     = {}
}
