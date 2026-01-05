output "alb_dns_name" {
  value = aws_lb.main.dns_name
}

output "alb_arn_suffix" {
  value = aws_lb.main.arn_suffix
}

output "target_group_arns" {
  value = { for k, v in aws_lb_target_group.main : k => v.arn }
}
