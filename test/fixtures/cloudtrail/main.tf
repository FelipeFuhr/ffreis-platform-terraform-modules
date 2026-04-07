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