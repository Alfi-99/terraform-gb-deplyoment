# =============================================================================
# APPLICATION LOAD BALANCER
# Mendistribusikan traffic ke environment Blue atau Green
# Ini adalah "switch" utama dalam arsitektur Blue/Green deployment
# =============================================================================

# Application Load Balancer (di Public Subnet)
resource "aws_lb" "main" {
  name               = "${local.name_prefix}-alb"
  internal           = false # Public-facing
  load_balancer_type = "application"
  security_groups    = [aws_security_group.alb.id]
  subnets            = aws_subnet.public[*].id

  # Enable deletion protection di production
  enable_deletion_protection = false # Set ke true di production sebenarnya

  # Enable access logs
  access_logs {
    bucket  = aws_s3_bucket.deployment.bucket
    prefix  = "alb-logs"
    enabled = true
  }

  tags = {
    Name = "${local.name_prefix}-alb"
  }
}

# ---------------------------------------------------------------------------
# Target Groups - Satu untuk Blue, satu untuk Green
# ---------------------------------------------------------------------------

# Target Group BLUE
resource "aws_lb_target_group" "blue" {
  name        = "${substr(local.name_prefix, 0, 24)}-blue"
  port        = 80
  protocol    = "HTTP"
  vpc_id      = aws_vpc.main.id
  target_type = "instance"

  health_check {
    enabled             = true
    healthy_threshold   = 2
    interval            = 30
    matcher             = "200"
    path                = "/health"
    port                = "traffic-port"
    protocol            = "HTTP"
    timeout             = 5
    unhealthy_threshold = 3
  }

  deregistration_delay = 30

  tags = {
    Name  = "${local.name_prefix}-blue-tg"
    Color = "blue"
  }
}

# Target Group GREEN
resource "aws_lb_target_group" "green" {
  name        = "${substr(local.name_prefix, 0, 24)}-green"
  port        = 80
  protocol    = "HTTP"
  vpc_id      = aws_vpc.main.id
  target_type = "instance"

  health_check {
    enabled             = true
    healthy_threshold   = 2
    interval            = 30
    matcher             = "200"
    path                = "/health"
    port                = "traffic-port"
    protocol            = "HTTP"
    timeout             = 5
    unhealthy_threshold = 3
  }

  deregistration_delay = 30

  tags = {
    Name  = "${local.name_prefix}-green-tg"
    Color = "green"
  }
}

# ---------------------------------------------------------------------------
# ALB Listeners
# ---------------------------------------------------------------------------

# Listener HTTP (port 80) - Redirect ke HTTPS atau forward ke active target group
resource "aws_lb_listener" "http" {
  load_balancer_arn = aws_lb.main.arn
  port              = "80"
  protocol          = "HTTP"

  # Forward ke active environment (Blue atau Green)
  default_action {
    type = "forward"

    forward {
      target_group {
        arn    = aws_lb_target_group.blue.arn
        weight = var.active_color == "blue" ? 100 : 0
      }

      target_group {
        arn    = aws_lb_target_group.green.arn
        weight = var.active_color == "green" ? 100 : 0
      }

      # Stickiness untuk session (opsional)
      stickiness {
        enabled  = false
        duration = 1
      }
    }
  }
}

# Listener Rule: Route /api/* ke API Gateway (melalui header rewrite)
# Catatan: Dalam production, gunakan HTTPS listener
resource "aws_lb_listener_rule" "api_route" {
  listener_arn = aws_lb_listener.http.arn
  priority     = 100

  action {
    type             = "redirect"
    redirect {
      host        = "${aws_api_gateway_rest_api.main.id}.execute-api.${var.aws_region}.amazonaws.com"
      path        = "/#{path}"
      port        = "443"
      protocol    = "HTTPS"
      query       = "#{query}"
      status_code = "HTTP_301"
    }
  }

  condition {
    path_pattern {
      values = ["/api/*"]
    }
  }
}
