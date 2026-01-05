output "queue_url" {
  description = "SQS queue URL"
  value       = aws_sqs_queue.main.url
}

output "queue_arn" {
  description = "SQS queue ARN"
  value       = aws_sqs_queue.main.arn
}

output "queue_name" {
  description = "SQS queue name"
  value       = aws_sqs_queue.main.name
}

output "dlq_url" {
  description = "Dead letter queue URL"
  value       = var.enable_dlq ? aws_sqs_queue.dlq[0].url : null
}

output "dlq_arn" {
  description = "Dead letter queue ARN"
  value       = var.enable_dlq ? aws_sqs_queue.dlq[0].arn : null
}
