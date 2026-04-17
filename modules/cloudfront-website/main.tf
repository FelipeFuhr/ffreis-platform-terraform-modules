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

  managed_security_headers_policy_name = "Managed-SecurityHeadersPolicy"

  # Strip the https:// scheme and trailing slash to get the plain hostname CloudFront needs
  # API Gateway v2 invoke URLs include a trailing slash: https://abc123.execute-api.region.amazonaws.com/
  api_domain = var.api_gateway_url != null ? trimsuffix(replace(var.api_gateway_url, "https://", ""), "/") : ""

  has_custom_domain      = length(var.domain_names) > 0
  has_api                = var.api_gateway_url != null && length(var.api_path_patterns) > 0
  s3_access_logs_prefix  = var.s3_access_logs_prefix != "" ? var.s3_access_logs_prefix : "${var.bucket_name}/s3/"
  cloudfront_logs_prefix = var.cloudfront_access_logs_prefix != "" ? var.cloudfront_access_logs_prefix : "${var.bucket_name}/cloudfront/"
}

# ---------------------------------------------------------------------------
# S3 bucket (private — CloudFront is the only reader via OAC)
# ---------------------------------------------------------------------------

data "aws_cloudfront_response_headers_policy" "security_headers" {
  name = local.managed_security_headers_policy_name
}

#trivy:ignore:*
resource "aws_s3_bucket" "website" {
  #checkov:skip=CKV_AWS_144:Cross-region replication requires a caller-managed destination bucket and provider configuration.
  #checkov:skip=CKV2_AWS_62:Static website buckets do not emit native event notifications by default; integrations are caller-specific.
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
      # Use SSE-S3 (AES256) by default — always compatible with CloudFront OAC.
      # KMS encryption requires the key policy to grant CloudFront decrypt access,
      # which the AWS-managed S3 key (alias/aws/s3) does support, but custom CMKs
      # need explicit policy statements. SSE-S3 avoids this complexity for static websites.
      kms_master_key_id = var.kms_key_arn
      sse_algorithm     = var.kms_key_arn != null ? "aws:kms" : "AES256"
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

resource "aws_s3_bucket_lifecycle_configuration" "website" {
  bucket = aws_s3_bucket.website.id

  rule {
    id     = "website-hygiene"
    status = "Enabled"

    filter {}

    noncurrent_version_expiration {
      noncurrent_days = 90
    }

    abort_incomplete_multipart_upload {
      days_after_initiation = 1
    }
  }
}

resource "aws_s3_bucket_logging" "website" {
  bucket        = aws_s3_bucket.website.id
  target_bucket = var.s3_access_logs_bucket_name
  target_prefix = local.s3_access_logs_prefix
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
#trivy:ignore:*
# nosemgrep: terraform.aws.security.aws-cloudfront-insecure-tls.aws-insecure-cloudfront-distribution-tls-version
resource "aws_cloudfront_distribution" "website" {
  #checkov:skip=CKV_AWS_310:Origin failover only applies when the caller provides redundant origins; this module manages a single website origin plus an optional API origin.
  #checkov:skip=CKV2_AWS_32:All cache behaviors attach the AWS managed Security Headers response policy; some scanner versions do not resolve the data source reference.
  #checkov:skip=CKV2_AWS_47:Log4j AMR enforcement is part of the caller-managed WAF policy, not this distribution module.
  enabled             = true
  is_ipv6_enabled     = true
  default_root_object = var.default_root_object
  price_class         = var.price_class
  aliases             = local.has_custom_domain ? var.domain_names : null
  web_acl_id          = var.waf_web_acl_id

  # S3 origin
  origin {
    domain_name              = aws_s3_bucket.website.bucket_regional_domain_name
    origin_id                = "S3-${var.bucket_name}"
    origin_access_control_id = aws_cloudfront_origin_access_control.website.id
    s3_origin_config {
      origin_access_identity = ""
    }
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
    target_origin_id           = "S3-${var.bucket_name}"
    viewer_protocol_policy     = "redirect-to-https"
    allowed_methods            = ["GET", "HEAD", "OPTIONS"]
    cached_methods             = ["GET", "HEAD"]
    cache_policy_id            = local.cache_policy_optimized
    response_headers_policy_id = data.aws_cloudfront_response_headers_policy.security_headers.id
    compress                   = true
  }

  # API path behaviours — forward POST/etc to API Gateway without caching
  dynamic "ordered_cache_behavior" {
    for_each = local.has_api ? var.api_path_patterns : []
    content {
      path_pattern               = ordered_cache_behavior.value
      target_origin_id           = "APIGW"
      viewer_protocol_policy     = "https-only"
      allowed_methods            = ["DELETE", "GET", "HEAD", "OPTIONS", "PATCH", "POST", "PUT"]
      cached_methods             = ["GET", "HEAD"]
      cache_policy_id            = local.cache_policy_disabled
      origin_request_policy_id   = local.origin_request_policy_all_except_host
      response_headers_policy_id = data.aws_cloudfront_response_headers_policy.security_headers.id
      compress                   = false
    }
  }

  # Custom error pages served from S3
  # NOTE: If a custom error page (e.g., /404.html) itself returns an error (e.g.,
  # because it doesn't exist in the bucket), CloudFront will return the raw S3
  # XML error response. Always ensure error pages are deployed before the
  # distribution is enabled or updated.
  custom_error_response {
    error_code            = 403
    response_code         = 404
    response_page_path    = var.not_found_page
    error_caching_min_ttl = var.error_caching_min_ttl
  }

  custom_error_response {
    error_code            = 404
    response_code         = 404
    response_page_path    = var.not_found_page
    error_caching_min_ttl = var.error_caching_min_ttl
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
    # AWS only allows TLSv1 when using the CloudFront default certificate. Custom
    # domains must provide ACM so the module can enforce a modern policy.
    minimum_protocol_version = local.has_custom_domain ? "TLSv1.2_2021" : "TLSv1"
  }

  logging_config {
    bucket          = var.cloudfront_access_logs_bucket_domain_name
    include_cookies = false
    prefix          = local.cloudfront_logs_prefix
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
