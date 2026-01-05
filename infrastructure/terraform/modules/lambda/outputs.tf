output "function_arns" {
  description = "Lambda function ARNs"
  value       = { for k, v in aws_lambda_function.function : k => v.arn }
}

output "function_names" {
  description = "Lambda function names"
  value       = [for v in aws_lambda_function.function : v.function_name]
}

output "role_arns" {
  description = "Lambda IAM role ARNs"
  value       = { for k, v in aws_iam_role.lambda : k => v.arn }
}
