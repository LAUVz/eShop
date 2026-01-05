# Lambda Functions for Background Processing

data "aws_iam_policy_document" "lambda_assume_role" {
  statement {
    effect = "Allow"

    principals {
      type        = "Service"
      identifiers = ["lambda.amazonaws.com"]
    }

    actions = ["sts:AssumeRole"]
  }
}

resource "aws_iam_role" "lambda" {
  for_each = var.functions

  name               = "${var.name_prefix}-lambda-${each.key}"
  assume_role_policy = data.aws_iam_policy_document.lambda_assume_role.json

  tags = var.tags
}

resource "aws_iam_role_policy_attachment" "lambda_basic" {
  for_each = var.functions

  role       = aws_iam_role.lambda[each.key].name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AWSLambdaBasicExecutionRole"
}

resource "aws_iam_role_policy_attachment" "lambda_sqs" {
  for_each = var.functions

  role       = aws_iam_role.lambda[each.key].name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AWSLambdaSQSQueueExecutionRole"
}

resource "aws_lambda_function" "function" {
  for_each = var.functions

  function_name = "${var.name_prefix}-${each.key}"
  role          = aws_iam_role.lambda[each.key].arn
  package_type  = "Image"

  # Use container image from ECR
  image_uri     = "${var.ecr_repository_urls[each.key]}:latest"
  memory_size   = each.value.memory_size
  timeout       = each.value.timeout

  environment {
    variables = each.value.environment
  }

  # Allow updates without recreating the function
  lifecycle {
    ignore_changes = [image_uri]
  }

  tags = var.tags
}

resource "aws_lambda_event_source_mapping" "sqs" {
  for_each = var.functions

  event_source_arn = var.sqs_queue_arn
  function_name    = aws_lambda_function.function[each.key].arn
  batch_size       = 10
}

