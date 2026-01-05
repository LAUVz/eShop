output "repository_urls" {
  description = "ECR repository URLs"
  value       = { for k, v in aws_ecr_repository.service : k => v.repository_url }
}

output "repository_arns" {
  description = "ECR repository ARNs"
  value       = { for k, v in aws_ecr_repository.service : k => v.arn }
}

output "repository_names" {
  description = "ECR repository names"
  value       = [for v in aws_ecr_repository.service : v.name]
}
