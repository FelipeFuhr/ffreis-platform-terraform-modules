terraform {
  required_version = ">= 1.5.0, < 2.0.0"

  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = ">= 5.0"
    }
  }
}

provider "aws" {
  region = var.aws_region
}

data "aws_caller_identity" "current" {}
data "aws_partition" "current" {}

locals {
  trail_logs_prefix = "${var.trail_name}/AWSLogs/${data.aws_caller_identity.current.account_id}/*"
}

#trivy:ignore:*
#checkov:skip=CKV_AWS_144:This ephemeral Terratest fixture uses a single temporary bucket and does not provision the caller-managed replication destination required for CRR.
#checkov:skip=CKV2_AWS_62:CloudTrail delivers logs directly to S3 and does not require bucket event notifications for this fixture.
#checkov:skip=CKV_AWS_18:This ephemeral fixture bucket does not emit access logs because that would require a second dedicated logging bucket just for the test harness.
resource "aws_s3_bucket" "trail" {
  bucket        = var.bucket_name
  force_destroy = true
  tags          = var.tags
}

resource "aws_s3_bucket_public_access_block" "trail" {
  bucket                  = aws_s3_bucket.trail.id
  block_public_acls       = true
  block_public_policy     = true
  ignore_public_acls      = true
  restrict_public_buckets = true
}

resource "aws_s3_bucket_server_side_encryption_configuration" "trail" {
  bucket = aws_s3_bucket.trail.id

  rule {
    apply_server_side_encryption_by_default {
      kms_master_key_id = aws_kms_key.trail.arn
      sse_algorithm     = "aws:kms"
    }
  }
}

resource "aws_s3_bucket_lifecycle_configuration" "trail" {
  bucket = aws_s3_bucket.trail.id

  rule {
    id     = "fixture-hygiene"
    status = "Enabled"

    filter {}

    abort_incomplete_multipart_upload {
      days_after_initiation = 1
    }
  }
}

resource "aws_s3_bucket_versioning" "trail" {
  bucket = aws_s3_bucket.trail.id

  versioning_configuration {
    status = "Enabled"
  }
}

data "aws_iam_policy_document" "trail_bucket" {
  statement {
    sid    = "AllowCloudTrailAclCheck"
    effect = "Allow"

    principals {
      type        = "Service"
      identifiers = ["cloudtrail.amazonaws.com"]
    }

    actions   = ["s3:GetBucketAcl"]
    resources = [aws_s3_bucket.trail.arn]
  }

  statement {
    sid    = "AllowCloudTrailWrite"
    effect = "Allow"

    principals {
      type        = "Service"
      identifiers = ["cloudtrail.amazonaws.com"]
    }

    actions   = ["s3:PutObject"]
    resources = ["${aws_s3_bucket.trail.arn}/${local.trail_logs_prefix}"]

    condition {
      test     = "StringEquals"
      variable = "s3:x-amz-acl"
      values   = ["bucket-owner-full-control"]
    }
  }
}

resource "aws_s3_bucket_policy" "trail" {
  bucket = aws_s3_bucket.trail.id
  policy = data.aws_iam_policy_document.trail_bucket.json
}

#trivy:ignore:*
#checkov:skip=CKV_AWS_356:KMS key policies are attached to the key itself and must use '*' resources by AWS design.
#checkov:skip=CKV_AWS_111:This test fixture key policy is constrained by principals and is required for CloudTrail service access.
#checkov:skip=CKV_AWS_109:KMS key policies require wildcard resources on the key policy document; permissions are constrained by principals and usage context.
data "aws_iam_policy_document" "trail_kms" {
  statement {
    sid       = "EnableRootPermissions"
    effect    = "Allow"
    actions   = ["kms:*"]
    resources = ["*"]

    principals {
      type        = "AWS"
      identifiers = ["arn:${data.aws_partition.current.partition}:iam::${data.aws_caller_identity.current.account_id}:root"]
    }
  }

  statement {
    sid    = "AllowCloudTrailToUseKey"
    effect = "Allow"
    actions = [
      "kms:Encrypt",
      "kms:Decrypt",
      "kms:ReEncrypt*",
      "kms:GenerateDataKey*",
      "kms:DescribeKey",
    ]
    resources = ["*"]

    principals {
      type        = "Service"
      identifiers = ["cloudtrail.amazonaws.com"]
    }
  }
}

resource "aws_kms_key" "trail" {
  description             = "Terratest key for CloudTrail module"
  deletion_window_in_days = 7
  enable_key_rotation     = true
  policy                  = data.aws_iam_policy_document.trail_kms.json
  tags                    = var.tags
}

#trivy:ignore:*
#checkov:skip=CKV_AWS_67:This Terratest fixture intentionally sets a single-region trail to keep AWS cost and test blast radius low while still exercising the module.
module "cloudtrail" {
  source = "../../../modules/cloudtrail"

  name                  = var.trail_name
  s3_bucket_name        = aws_s3_bucket.trail.id
  kms_key_arn           = aws_kms_key.trail.arn
  is_multi_region_trail = false
  tags                  = var.tags

  depends_on = [aws_s3_bucket_policy.trail]
}

output "trail_arn" {
  value = module.cloudtrail.trail_arn
}

output "trail_name" {
  value = module.cloudtrail.trail_name
}

output "cloudwatch_log_group_name" {
  value = "/cloudtrail/${module.cloudtrail.trail_name}"
}

variable "aws_region" {
  type = string
}

variable "trail_name" {
  type = string
}

variable "bucket_name" {
  type = string
}

variable "tags" {
  type = map(string)
}