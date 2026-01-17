# Application Load Balancer

resource "aws_lb" "main" {
  name               = "${var.name_prefix}-alb"
  internal           = false
  load_balancer_type = "application"
  security_groups    = var.security_group_ids
  subnets            = var.public_subnet_ids

  tags = var.tags
}

# Target groups for each service that uses ALB
resource "aws_lb_target_group" "main" {
  for_each = var.services

  name     = "${var.name_prefix}-${each.key}"
  port     = each.value.port
  protocol = "HTTP"
  vpc_id   = var.vpc_id
  target_type = "ip"

  health_check {
    path                = each.value.health_check
    healthy_threshold   = 2
    unhealthy_threshold = 3
    timeout             = 5
    interval            = 30
  }

  tags = var.tags
}

# HTTP listener with default action to webapp
resource "aws_lb_listener" "http" {
  load_balancer_arn = aws_lb.main.arn
  port              = 80
  protocol          = "HTTP"

  default_action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.main["webapp"].arn
  }
}

# Path-based routing rules (ordered by priority)
# Identity API - handles authentication/authorization
resource "aws_lb_listener_rule" "identity_api" {
  count        = contains(keys(var.services), "identity-api") ? 1 : 0
  listener_arn = aws_lb_listener.http.arn
  priority     = 10

  action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.main["identity-api"].arn
  }

  condition {
    path_pattern {
      values = ["/.well-known/*", "/connect/*", "/Account/*", "/Manage/*"]
    }
  }
}

# Catalog API - product catalog
resource "aws_lb_listener_rule" "catalog_api" {
  count        = contains(keys(var.services), "catalog-api") ? 1 : 0
  listener_arn = aws_lb_listener.http.arn
  priority     = 20

  action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.main["catalog-api"].arn
  }

  condition {
    path_pattern {
      values = ["/api/catalog/*"]
    }
  }
}

# Basket API - shopping cart
resource "aws_lb_listener_rule" "basket_api" {
  count        = contains(keys(var.services), "basket-api") ? 1 : 0
  listener_arn = aws_lb_listener.http.arn
  priority     = 30

  action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.main["basket-api"].arn
  }

  condition {
    path_pattern {
      values = ["/api/basket/*"]
    }
  }
}

# Ordering API - order management
resource "aws_lb_listener_rule" "ordering_api" {
  count        = contains(keys(var.services), "ordering-api") ? 1 : 0
  listener_arn = aws_lb_listener.http.arn
  priority     = 40

  action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.main["ordering-api"].arn
  }

  condition {
    path_pattern {
      values = ["/api/orders/*"]
    }
  }
}

# Webhooks API - webhook management
resource "aws_lb_listener_rule" "webhooks_api" {
  count        = contains(keys(var.services), "webhooks-api") ? 1 : 0
  listener_arn = aws_lb_listener.http.arn
  priority     = 50

  action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.main["webhooks-api"].arn
  }

  condition {
    path_pattern {
      values = ["/api/webhooks/*"]
    }
  }
}
