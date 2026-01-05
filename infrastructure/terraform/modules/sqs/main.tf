# SQS Queues for Event Messaging

resource "aws_sqs_queue" "main" {
  name                       = "${var.name_prefix}-events"
  visibility_timeout_seconds = var.visibility_timeout_seconds
  message_retention_seconds  = var.message_retention_seconds
  max_message_size           = var.max_message_size
  delay_seconds              = var.delay_seconds
  receive_wait_time_seconds  = var.receive_wait_time_seconds

  tags = var.tags
}

resource "aws_sqs_queue" "dlq" {
  count = var.enable_dlq ? 1 : 0

  name                       = "${var.name_prefix}-events-dlq"
  message_retention_seconds  = 1209600  # 14 days

  tags = var.tags
}

resource "aws_sqs_queue_redrive_policy" "main" {
  count = var.enable_dlq ? 1 : 0

  queue_url = aws_sqs_queue.main.id
  redrive_policy = jsonencode({
    deadLetterTargetArn = aws_sqs_queue.dlq[0].arn
    maxReceiveCount     = var.max_receive_count
  })
}
