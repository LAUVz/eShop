variable "name_prefix" {
  description = "Prefix for resource names"
  type        = string
}

variable "visibility_timeout_seconds" {
  description = "Visibility timeout in seconds"
  type        = number
  default     = 30
}

variable "message_retention_seconds" {
  description = "Message retention period in seconds"
  type        = number
  default     = 345600  # 4 days
}

variable "max_message_size" {
  description = "Maximum message size in bytes"
  type        = number
  default     = 262144  # 256 KB
}

variable "delay_seconds" {
  description = "Delay seconds for message delivery"
  type        = number
  default     = 0
}

variable "receive_wait_time_seconds" {
  description = "Wait time for receive message in seconds"
  type        = number
  default     = 0
}

variable "enable_dlq" {
  description = "Enable dead letter queue"
  type        = bool
  default     = true
}

variable "max_receive_count" {
  description = "Maximum receives before moving to DLQ"
  type        = number
  default     = 3
}

variable "tags" {
  description = "Tags to apply to resources"
  type        = map(string)
  default     = {}
}
