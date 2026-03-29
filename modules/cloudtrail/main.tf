data "aws_caller_identity" "current" {}
data "aws_partition" "current" {}
data "aws_region" "current" {}

locals {
  s3_prefix = var.s3_key_prefix != "" ? var.s3_key_prefix : var.name

  iam_effect_allow           = "Allow"
  iam_action_sts_assume_role = "sts:AssumeRole"
  iam_principal_type_service = "Service"
}

# ---------------------------------------------------------------------------
# CloudWatch Logs destination (optional)
# ---------------------------------------------------------------------------
resource "aws_cloudwatch_log_group" "trail" {
  count             = var.enable_cloudwatch_logs ? 1 : 0
  name              = "/cloudtrail/${var.name}"
  retention_in_days = var.cloudwatch_logs_retention_days
  kms_key_id        = var.cloudwatch_logs_kms_key_arn

  tags = var.tags
}

data "aws_iam_policy_document" "cloudtrail_assume" {
  count = var.enable_cloudwatch_logs ? 1 : 0

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
  count = var.enable_cloudwatch_logs ? 1 : 0

  statement {
    effect = local.iam_effect_allow
    actions = [
      "logs:CreateLogStream",
      "logs:PutLogEvents",
    ]
    resources = ["${aws_cloudwatch_log_group.trail[0].arn}:*"]
  }
}

resource "aws_iam_role" "cloudtrail" {
  count              = var.enable_cloudwatch_logs ? 1 : 0
  name               = "${var.name}-cloudtrail-cw"
  assume_role_policy = data.aws_iam_policy_document.cloudtrail_assume[0].json
  tags               = var.tags
}

resource "aws_iam_role_policy" "cloudtrail_logs" {
  count  = var.enable_cloudwatch_logs ? 1 : 0
  name   = "write-cloudtrail-logs"
  role   = aws_iam_role.cloudtrail[0].id
  policy = data.aws_iam_policy_document.cloudtrail_logs_write[0].json
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

  cloud_watch_logs_group_arn = var.enable_cloudwatch_logs ? "${aws_cloudwatch_log_group.trail[0].arn}:*" : null
  cloud_watch_logs_role_arn  = var.enable_cloudwatch_logs ? aws_iam_role.cloudtrail[0].arn : null

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
}
