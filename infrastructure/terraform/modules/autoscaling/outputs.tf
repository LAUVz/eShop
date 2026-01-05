output "scaling_target_ids" {
  value = { for k, v in aws_appautoscaling_target.ecs : k => v.id }
}
