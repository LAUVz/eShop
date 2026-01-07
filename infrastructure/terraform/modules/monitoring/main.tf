# CloudWatch Monitoring and Alarms

# SNS Topic for alerts
resource "aws_sns_topic" "alerts" {
  name = "${var.project_name}-${var.environment}-alerts"
  tags = var.common_tags
}

resource "aws_sns_topic_subscription" "email" {
  topic_arn = aws_sns_topic.alerts.arn
  protocol  = "email"
  endpoint  = var.sns_email_endpoint
}

# CloudWatch Dashboard
resource "aws_cloudwatch_dashboard" "main" {
  dashboard_name = "${var.project_name}-${var.environment}"

  dashboard_body = jsonencode({
    widgets = [
      {
        type = "metric"
        properties = {
          metrics = [
            ["AWS/ECS", "CPUUtilization", { stat = "Average" }],
            [".", "MemoryUtilization", { stat = "Average" }]
          ]
          period = 300
          stat   = "Average"
          region = var.aws_region
          title  = "ECS Cluster Metrics"
        }
      }
    ]
  })
}

# Cost anomaly detection - DISABLED due to AWS account limits
# Uncomment if you need cost anomaly detection and have available quota
# resource "aws_ce_anomaly_monitor" "cost" {
#   name              = "${var.project_name}-cost-monitor"
#   monitor_type      = "DIMENSIONAL"
#   monitor_dimension = "SERVICE"
# }
#
# resource "aws_ce_anomaly_subscription" "cost" {
#   name      = "${var.project_name}-cost-alerts"
#   frequency = "DAILY"
#
#   monitor_arn_list = [
#     aws_ce_anomaly_monitor.cost.arn,
#   ]
#
#   threshold_expression {
#     dimension {
#       key           = "ANOMALY_TOTAL_IMPACT_ABSOLUTE"
#       values        = ["100"]
#       match_options = ["GREATER_THAN_OR_EQUAL"]
#     }
#   }
#
#   subscriber {
#     type    = "EMAIL"
#     address = var.sns_email_endpoint
#   }
# }
