# ---------------------------------------------------------------------------
# Application Load Balancer
# ---------------------------------------------------------------------------
resource "aws_lb" "this" {
  name = var.name
  # Trivy AWS-0053: avoid creating internet-facing load balancers from this
  # shared module (defence in depth).
  internal           = true
  load_balancer_type = "application"
  subnets            = var.subnet_ids
  security_groups    = var.security_group_ids

  idle_timeout               = var.idle_timeout
  enable_deletion_protection = var.enable_deletion_protection
  drop_invalid_header_fields = var.drop_invalid_header_fields

  dynamic "access_logs" {
    for_each = var.access_logs_bucket != "" ? [1] : []
    content {
      bucket  = var.access_logs_bucket
      prefix  = var.access_logs_prefix != "" ? var.access_logs_prefix : var.name
      enabled = true
    }
  }

  tags = var.tags
}

resource "aws_wafv2_web_acl_association" "this" {
  count        = var.waf_acl_arn != null ? 1 : 0
  resource_arn = aws_lb.this.arn
  web_acl_arn  = var.waf_acl_arn
}

# ---------------------------------------------------------------------------
# Target groups
# ---------------------------------------------------------------------------
resource "aws_lb_target_group" "this" {
  for_each = var.target_groups

  name                 = "${var.name}-${each.key}"
  port                 = each.value.port
  protocol             = each.value.protocol
  target_type          = each.value.target_type
  vpc_id               = var.vpc_id
  deregistration_delay = each.value.deregistration_delay

  health_check {
    path                = each.value.health_check.path
    protocol            = each.value.health_check.protocol
    matcher             = each.value.health_check.matcher
    interval            = each.value.health_check.interval
    timeout             = each.value.health_check.timeout
    healthy_threshold   = each.value.health_check.healthy_threshold
    unhealthy_threshold = each.value.health_check.unhealthy_threshold
  }

  dynamic "stickiness" {
    for_each = each.value.stickiness != null ? [each.value.stickiness] : []
    content {
      type            = "lb_cookie"
      enabled         = stickiness.value.enabled
      cookie_duration = stickiness.value.duration
    }
  }

  lifecycle {
    create_before_destroy = true
  }

  tags = var.tags
}

# ---------------------------------------------------------------------------
# HTTP listener — always redirects to HTTPS.
# ---------------------------------------------------------------------------
resource "aws_lb_listener" "http" {
  count             = 1
  load_balancer_arn = aws_lb.this.arn
  port              = 80
  protocol          = "HTTP"

  default_action {
    type = "redirect"
    redirect {
      port        = "443"
      protocol    = "HTTPS"
      status_code = "HTTP_301"
    }
  }

  tags = var.tags
}

# ---------------------------------------------------------------------------
# HTTPS listener
# ---------------------------------------------------------------------------
resource "aws_lb_listener" "https" {
  count             = 1
  load_balancer_arn = aws_lb.this.arn
  port              = 443
  protocol          = "HTTPS"
  # Enforce a modern TLS policy (TLS 1.2/1.3 only).
  ssl_policy        = "ELBSecurityPolicy-TLS13-1-2-Res-2021-06"
  certificate_arn   = var.certificate_arn

  # Default: return 404 — explicit rules below direct traffic.
  default_action {
    type = "fixed-response"
    fixed_response {
      content_type = "text/plain"
      message_body = "Not Found"
      status_code  = "404"
    }
  }

  tags = var.tags
}

# ---------------------------------------------------------------------------
# Listener rules on the HTTPS listener
# ---------------------------------------------------------------------------
resource "aws_lb_listener_rule" "https" {
  for_each = var.https_listener_rules

  listener_arn = aws_lb_listener.https[0].arn
  priority     = each.value.priority

  action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.this[each.value.target_group].arn
  }

  dynamic "condition" {
    for_each = each.value.conditions
    content {
      dynamic "path_pattern" {
        for_each = condition.value.field == "path-pattern" ? [condition.value.values] : []
        content { values = path_pattern.value }
      }
      dynamic "host_header" {
        for_each = condition.value.field == "host-header" ? [condition.value.values] : []
        content { values = host_header.value }
      }
    }
  }

  tags = var.tags
}
