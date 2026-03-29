resource "aws_acm_certificate" "this" {
  domain_name               = var.domain_name
  subject_alternative_names = var.subject_alternative_names
  validation_method         = var.validation_method
  key_algorithm             = var.key_algorithm

  # Always recreate before destroying to avoid downtime on ALB/CloudFront.
  lifecycle {
    create_before_destroy = true
  }

  tags = var.tags
}

# ---------------------------------------------------------------------------
# DNS validation records (only when Route 53 zone ID is provided)
# ---------------------------------------------------------------------------
resource "aws_route53_record" "validation" {
  for_each = (
    var.validation_method == "DNS" && var.hosted_zone_id != null
    ? {
        for dvo in aws_acm_certificate.this.domain_validation_options :
        dvo.domain_name => {
          name   = dvo.resource_record_name
          type   = dvo.resource_record_type
          record = dvo.resource_record_value
        }
      }
    : {}
  )

  zone_id = var.hosted_zone_id
  name    = each.value.name
  type    = each.value.type
  records = [each.value.record]
  ttl     = 60

  allow_overwrite = true
}

resource "aws_acm_certificate_validation" "this" {
  count = (var.wait_for_validation && var.validation_method == "DNS" && var.hosted_zone_id != null) ? 1 : 0

  certificate_arn         = aws_acm_certificate.this.arn
  validation_record_fqdns = [for r in aws_route53_record.validation : r.fqdn]
}
