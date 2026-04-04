# ---------------------------------------------------------------------------
# Managed CloudFront cache policy IDs (stable AWS-managed values)
# ---------------------------------------------------------------------------
locals {
  # AWS managed: CachingOptimized — used for static S3 content
  cache_policy_optimized = "658327ea-f89d-4fab-a63d-7e88639e58f6"
  # AWS managed: CachingDisabled — used for API proxy behaviours
  cache_policy_disabled = "4135ea2d-6df8-44a3-9df3-4b5a84be39ad"
  # AWS managed: AllViewerExceptHostHeader — forward all request headers to
  # the origin except Host, which CloudFront replaces with the origin domain
  origin_request_policy_all_except_host = "b689b0a8-53d0-40ab-baf2-68738e2966ac"

  # Strip the https:// scheme to get the plain hostname CloudFront needs
  api_domain = var.api_gateway_url != null ? replace(var.api_gateway_url, "https://", "") : ""

  has_custom_domain = length(var.domain_names) > 0
  has_api           = var.api_gateway_url != null && length(var.api_path_patterns) > 0
}

# ---------------------------------------------------------------------------
# S3 bucket (private — CloudFront is the only reader via OAC)
# ---------------------------------------------------------------------------
resource "aws_s3_bucket" "website" {
  bucket        = var.bucket_name
  force_destroy = false

  tags = var.tags
}

resource "aws_s3_bucket_versioning" "website" {
  bucket = aws_s3_bucket.website.id
  versioning_configuration {
    status = "Enabled"
  }
}

resource "aws_s3_bucket_server_side_encryption_configuration" "website" {
  bucket = aws_s3_bucket.website.id
  rule {
    apply_server_side_encryption_by_default {
      sse_algorithm = "AES256"
    }
  }
}

resource "aws_s3_bucket_public_access_block" "website" {
  bucket                  = aws_s3_bucket.website.id
  block_public_acls       = true
  block_public_policy     = true
  ignore_public_acls      = true
  restrict_public_buckets = true
}

# ---------------------------------------------------------------------------
# CloudFront Origin Access Control (OAC) — modern replacement for OAI
# ---------------------------------------------------------------------------
resource "aws_cloudfront_origin_access_control" "website" {
  name                              = "${var.bucket_name}-oac"
  description                       = "OAC for ${var.bucket_name}"
  origin_access_control_origin_type = "s3"
  signing_behavior                  = "always"
  signing_protocol                  = "sigv4"
}

# ---------------------------------------------------------------------------
# CloudFront distribution
# ---------------------------------------------------------------------------
resource "aws_cloudfront_distribution" "website" {
  enabled             = true
  is_ipv6_enabled     = true
  default_root_object = var.default_root_object
  price_class         = var.price_class
  aliases             = local.has_custom_domain ? var.domain_names : null

  # S3 origin
  origin {
    domain_name              = aws_s3_bucket.website.bucket_regional_domain_name
    origin_id                = "S3-${var.bucket_name}"
    origin_access_control_id = aws_cloudfront_origin_access_control.website.id
  }

  # API Gateway origin (conditional)
  dynamic "origin" {
    for_each = local.has_api ? [1] : []
    content {
      domain_name = local.api_domain
      origin_id   = "APIGW"
      custom_origin_config {
        http_port              = 80
        https_port             = 443
        origin_protocol_policy = "https-only"
        origin_ssl_protocols   = ["TLSv1.2"]
      }
    }
  }

  # Default behaviour — serve static files from S3
  default_cache_behavior {
    target_origin_id       = "S3-${var.bucket_name}"
    viewer_protocol_policy = "redirect-to-https"
    allowed_methods        = ["GET", "HEAD", "OPTIONS"]
    cached_methods         = ["GET", "HEAD"]
    cache_policy_id        = local.cache_policy_optimized
    compress               = true
  }

  # API path behaviours — forward POST/etc to API Gateway without caching
  dynamic "ordered_cache_behavior" {
    for_each = local.has_api ? var.api_path_patterns : []
    content {
      path_pattern             = ordered_cache_behavior.value
      target_origin_id         = "APIGW"
      viewer_protocol_policy   = "https-only"
      allowed_methods          = ["DELETE", "GET", "HEAD", "OPTIONS", "PATCH", "POST", "PUT"]
      cached_methods           = ["GET", "HEAD"]
      cache_policy_id          = local.cache_policy_disabled
      origin_request_policy_id = local.origin_request_policy_all_except_host
      compress                 = false
    }
  }

  # Custom error pages served from S3
  custom_error_response {
    error_code            = 403
    response_code         = 404
    response_page_path    = var.not_found_page
    error_caching_min_ttl = 10
  }

  custom_error_response {
    error_code            = 404
    response_code         = 404
    response_page_path    = var.not_found_page
    error_caching_min_ttl = 10
  }

  custom_error_response {
    error_code            = 500
    response_code         = 500
    response_page_path    = var.error_page
    error_caching_min_ttl = 0
  }

  restrictions {
    geo_restriction {
      restriction_type = "none"
    }
  }

  viewer_certificate {
    acm_certificate_arn            = local.has_custom_domain ? var.acm_certificate_arn : null
    cloudfront_default_certificate = !local.has_custom_domain
    ssl_support_method             = local.has_custom_domain ? "sni-only" : null
    minimum_protocol_version       = local.has_custom_domain ? "TLSv1.2_2021" : null
  }

  tags = var.tags
}

# ---------------------------------------------------------------------------
# S3 bucket policy — grant CloudFront OAC read access; deny plain HTTP
# ---------------------------------------------------------------------------
resource "aws_s3_bucket_policy" "website" {
  bucket = aws_s3_bucket.website.id
  policy = data.aws_iam_policy_document.website_bucket.json

  depends_on = [aws_s3_bucket_public_access_block.website]
}

data "aws_iam_policy_document" "website_bucket" {
  statement {
    sid    = "AllowCloudFrontOAC"
    effect = "Allow"
    principals {
      type        = "Service"
      identifiers = ["cloudfront.amazonaws.com"]
    }
    actions   = ["s3:GetObject"]
    resources = ["${aws_s3_bucket.website.arn}/*"]
    condition {
      test     = "StringEquals"
      variable = "AWS:SourceArn"
      values   = [aws_cloudfront_distribution.website.arn]
    }
  }

  statement {
    sid    = "DenyHTTP"
    effect = "Deny"
    principals {
      type        = "*"
      identifiers = ["*"]
    }
    actions = ["s3:*"]
    resources = [
      aws_s3_bucket.website.arn,
      "${aws_s3_bucket.website.arn}/*",
    ]
    condition {
      test     = "Bool"
      variable = "aws:SecureTransport"
      values   = ["false"]
    }
  }
}
