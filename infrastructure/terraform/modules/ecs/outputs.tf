output "cluster_name" {
  value = aws_ecs_cluster.main.name
}

output "cluster_arn" {
  value = aws_ecs_cluster.main.arn
}

output "service_names" {
  value = [for v in aws_ecs_service.service : v.name]
}
