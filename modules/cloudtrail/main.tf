data "aws_caller_identity" "current" {}
data "aws_partition" "current" {}

locals {
  s3_prefix = var.s3_key_prefix != "" ? var.s3_key_prefix : var.name

  iam_effect_allow           = "Allow"
  iam_action_sts_assume_role = "sts:AssumeRole"
  iam_principal_type_service = "Service"

  cloudtrail_sns_kms_key_arn = var.sns_kms_key_arn != null ? var.sns_kms_key_arn : aws_kms_key.cloudtrail_sns[0].arn
}

# ---------------------------------------------------------------------------
# CloudWatch Logs destination
# Required by Checkov CKV2_AWS_10 (CloudTrail integrated with CloudWatch Logs).
# ---------------------------------------------------------------------------
resource "aws_cloudwatch_log_group" "trail" {
  name              = "/cloudtrail/${var.name}"
  retention_in_days = var.cloudwatch_logs_retention_days
  kms_key_id        = var.cloudwatch_logs_kms_key_arn

  tags = var.tags
}

data "aws_iam_policy_document" "cloudtrail_assume" {
  statement {
    effect  = local.iam_effect_allow
    actions = [local.iam_action_sts_assume_role]
    principals {
      type        = local.iam_principal_type_service
      identifiers = ["cloudtrail.amazonaws.com"]
    }
  }
}

data "aws_iam_policy_document" "cloudtrail_logs_write" {
  statement {
    effect = local.iam_effect_allow
    actions = [
      "logs:CreateLogStream",
      "logs:PutLogEvents",
    ]
    resources = ["${aws_cloudwatch_log_group.trail.arn}:*"]
  }
}

resource "aws_iam_role" "cloudtrail" {
  name               = "${var.name}-cloudtrail-cw"
  assume_role_policy = data.aws_iam_policy_document.cloudtrail_assume.json
  tags               = var.tags
}

resource "aws_iam_role_policy" "cloudtrail_logs" {
  name   = "write-cloudtrail-logs"
  role   = aws_iam_role.cloudtrail.id
  policy = data.aws_iam_policy_document.cloudtrail_logs_write.json
}

# ---------------------------------------------------------------------------
# SNS destination (required by Checkov CKV_AWS_252)
# ---------------------------------------------------------------------------
resource "aws_sns_topic" "cloudtrail" {
  name              = "${var.name}-cloudtrail"
  kms_master_key_id = local.cloudtrail_sns_kms_key_arn
  tags              = var.tags
}

data "aws_iam_policy_document" "cloudtrail_sns_kms_policy" {
  #checkov:skip=CKV_AWS_356:KMS key policies require '*' as resource; the policy is attached to the key and scoped to it by design.
  #checkov:skip=CKV_AWS_111:KMS key policies require '*' as resource; the policy is attached to the key and scoped to it by design.
  #checkov:skip=CKV_AWS_109:KMS key policies require '*' as resource; the policy is attached to the key and scoped to it by design.
  statement {
    sid       = "EnableRootPermissions"
    effect    = local.iam_effect_allow
    actions   = ["kms:*"]
    resources = ["*"]

    principals {
      type        = "AWS"
      identifiers = ["arn:${data.aws_partition.current.partition}:iam::${data.aws_caller_identity.current.account_id}:root"]
    }
  }

  statement {
    sid    = "AllowSNSToUseKey"
    effect = local.iam_effect_allow
    actions = [
      "kms:Encrypt",
      "kms:Decrypt",
      "kms:ReEncrypt*",
      "kms:GenerateDataKey*",
      "kms:DescribeKey",
    ]
    resources = ["*"]

    principals {
      type        = local.iam_principal_type_service
      identifiers = ["sns.amazonaws.com"]
    }

    condition {
      test     = "StringEquals"
      variable = "aws:SourceAccount"
      values   = [data.aws_caller_identity.current.account_id]
    }
  }
}

resource "aws_kms_key" "cloudtrail_sns" {
  count                   = var.sns_kms_key_arn == null ? 1 : 0
  description             = "KMS key for CloudTrail SNS topic encryption (${var.name})"
  deletion_window_in_days = 7
  enable_key_rotation     = true
  policy                  = data.aws_iam_policy_document.cloudtrail_sns_kms_policy.json
  tags                    = var.tags
}

resource "aws_kms_alias" "cloudtrail_sns" {
  count         = var.sns_kms_key_arn == null ? 1 : 0
  name          = "alias/${var.name}-cloudtrail-sns"
  target_key_id = aws_kms_key.cloudtrail_sns[0].key_id
}

data "aws_iam_policy_document" "cloudtrail_sns_policy" {
  statement {
    sid     = "AllowCloudTrailPublish"
    effect  = local.iam_effect_allow
    actions = ["sns:Publish"]

    principals {
      type        = local.iam_principal_type_service
      identifiers = ["cloudtrail.amazonaws.com"]
    }

    resources = [aws_sns_topic.cloudtrail.arn]
  }
}

resource "aws_sns_topic_policy" "cloudtrail" {
  arn    = aws_sns_topic.cloudtrail.arn
  policy = data.aws_iam_policy_document.cloudtrail_sns_policy.json
}

# ---------------------------------------------------------------------------
# CloudTrail trail
# ---------------------------------------------------------------------------
resource "aws_cloudtrail" "this" {
  name                          = var.name
  s3_bucket_name                = var.s3_bucket_name
  s3_key_prefix                 = local.s3_prefix
  is_multi_region_trail         = var.is_multi_region_trail
  include_global_service_events = var.include_global_service_events
  enable_log_file_validation    = var.enable_log_file_validation
  kms_key_id                    = var.kms_key_arn

  cloud_watch_logs_group_arn = "${aws_cloudwatch_log_group.trail.arn}:*"
  cloud_watch_logs_role_arn  = aws_iam_role.cloudtrail.arn
  sns_topic_name             = aws_sns_topic.cloudtrail.name

  dynamic "event_selector" {
    for_each = var.event_selectors
    content {
      read_write_type           = event_selector.value.read_write_type
      include_management_events = event_selector.value.include_management_events

      dynamic "data_resource" {
        for_each = event_selector.value.data_resources
        content {
          type   = data_resource.value.type
          values = data_resource.value.values
        }
      }
    }
  }

  tags = var.tags

  depends_on = [aws_sns_topic_policy.cloudtrail]
}
