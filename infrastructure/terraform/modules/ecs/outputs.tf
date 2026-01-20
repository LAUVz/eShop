output "cluster_name" {
  value = aws_ecs_cluster.main.name
}

output "cluster_arn" {
  value = aws_ecs_cluster.main.arn
}

output "service_name" {
  value = aws_ecs_service.app.name
  description = "Name of the multi-container ECS service"
}

output "service_id" {
  value = aws_ecs_service.app.id
  description = "ID of the multi-container ECS service"
}

# For compatibility with autoscaling module
output "service_ids" {
  value = { "app" = aws_ecs_service.app.id }
  description = "Service IDs map (single multi-container service)"
}
