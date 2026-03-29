# ---------------------------------------------------------------------------
# Bucket
# ---------------------------------------------------------------------------
resource "aws_s3_bucket" "this" {
  #checkov:skip=CKV_AWS_144:Cross-region replication requires a destination bucket/provider configuration; enforce at the stack level.
  #checkov:skip=CKV2_AWS_62:Event notifications depend on integration targets (SQS/SNS/Lambda) and are configured by the caller.
  bucket              = var.bucket
  force_destroy       = var.force_destroy
  object_lock_enabled = var.object_lock_enabled

  tags = var.tags
}

# ---------------------------------------------------------------------------
# Object Lock configuration (immutable storage / WORM)
# ---------------------------------------------------------------------------
resource "aws_s3_bucket_object_lock_configuration" "this" {
  count  = var.object_lock_enabled ? 1 : 0
  bucket = aws_s3_bucket.this.id

  rule {
    default_retention {
      mode  = var.object_lock_mode
      days  = var.object_lock_days > 0 ? var.object_lock_days : null
      years = var.object_lock_days == 0 ? var.object_lock_years : null
    }
  }
}

# ---------------------------------------------------------------------------
# Intelligent-Tiering configuration (optional — cost optimisation)
# ---------------------------------------------------------------------------
resource "aws_s3_bucket_intelligent_tiering_configuration" "this" {
  count  = var.intelligent_tiering ? 1 : 0
  bucket = aws_s3_bucket.this.id
  name   = "EntireBucket"

  tiering {
    access_tier = "ARCHIVE_ACCESS"
    days        = 90
  }
  tiering {
    access_tier = "DEEP_ARCHIVE_ACCESS"
    days        = 180
  }
}

# ---------------------------------------------------------------------------
# Public access block — always enabled; there is no safe reason to relax this
# for platform buckets.
# ---------------------------------------------------------------------------
resource "aws_s3_bucket_public_access_block" "this" {
  bucket = aws_s3_bucket.this.id

  block_public_acls       = true
  block_public_policy     = true
  ignore_public_acls      = true
  restrict_public_buckets = true
}

# ---------------------------------------------------------------------------
# Server-side encryption — always enabled.
# ---------------------------------------------------------------------------
resource "aws_s3_bucket_server_side_encryption_configuration" "this" {
  bucket = aws_s3_bucket.this.id

  rule {
    apply_server_side_encryption_by_default {
      sse_algorithm     = var.sse_algorithm
      kms_master_key_id = var.kms_master_key_id
    }
    bucket_key_enabled = true
  }
}

# ---------------------------------------------------------------------------
# Versioning
# ---------------------------------------------------------------------------
resource "aws_s3_bucket_versioning" "this" {
  bucket = aws_s3_bucket.this.id

  versioning_configuration {
    status = var.versioning_enabled ? "Enabled" : "Suspended"
  }
}

# ---------------------------------------------------------------------------
# TLS-only bucket policy — deny any request that does not use HTTPS.
# This is a defence-in-depth control: even if credentials are compromised,
# data cannot be intercepted in transit.
# ---------------------------------------------------------------------------
data "aws_iam_policy_document" "tls_enforce" {
  statement {
    sid     = "DenyHTTP"
    effect  = "Deny"
    actions = ["s3:*"]

    principals {
      type        = "*"
      identifiers = ["*"]
    }

    resources = [
      aws_s3_bucket.this.arn,
      "${aws_s3_bucket.this.arn}/*",
    ]

    condition {
      test     = "Bool"
      variable = "aws:SecureTransport"
      values   = ["false"]
    }
  }
}

resource "aws_s3_bucket_policy" "tls_enforce" {
  bucket = aws_s3_bucket.this.id
  policy = data.aws_iam_policy_document.tls_enforce.json

  # Policy must be set after the public access block to avoid "conflicting
  # operation" errors when the account-level block is also enabled.
  depends_on = [aws_s3_bucket_public_access_block.this]
}

# ---------------------------------------------------------------------------
# Lifecycle rules (optional)
# ---------------------------------------------------------------------------
resource "aws_s3_bucket_lifecycle_configuration" "this" {
  bucket = aws_s3_bucket.this.id

  dynamic "rule" {
    for_each = var.abort_incomplete_multipart_upload_days > 0 ? [1] : []
    content {
      id     = "abort-incomplete-multipart-uploads"
      status = "Enabled"

      abort_incomplete_multipart_upload {
        days_after_initiation = var.abort_incomplete_multipart_upload_days
      }
    }
  }

  dynamic "rule" {
    for_each = var.lifecycle_rules
    content {
      id     = rule.value.id
      status = rule.value.enabled ? "Enabled" : "Disabled"

      dynamic "expiration" {
        for_each = rule.value.expiration_days != null ? [rule.value.expiration_days] : []
        content {
          days = expiration.value
        }
      }

      dynamic "noncurrent_version_expiration" {
        for_each = rule.value.noncurrent_version_expiration_days != null ? [rule.value.noncurrent_version_expiration_days] : []
        content {
          noncurrent_days = noncurrent_version_expiration.value
        }
      }
    }
  }
}

# ---------------------------------------------------------------------------
# Access logging (optional)
# ---------------------------------------------------------------------------
resource "aws_s3_bucket_logging" "this" {
  count  = var.logging_target_bucket != "" ? 1 : 0
  bucket = aws_s3_bucket.this.id

  target_bucket = var.logging_target_bucket
  target_prefix = var.logging_target_prefix != "" ? var.logging_target_prefix : "${var.bucket}/"
}
