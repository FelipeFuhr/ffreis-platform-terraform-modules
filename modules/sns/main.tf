data "aws_caller_identity" "current" {}
data "aws_partition" "current" {}

locals {
  sns_kms_key_id = var.kms_master_key_id != null ? var.kms_master_key_id : aws_kms_key.sns[0].arn
}

data "aws_iam_policy_document" "sns_kms_policy" {
  #checkov:skip=CKV_AWS_356:KMS key policies require '*' as resource; the policy is attached to the key and scoped to it by design.
  #checkov:skip=CKV_AWS_111:KMS key policies require '*' as resource; the policy is attached to the key and scoped to it by design.
  #checkov:skip=CKV_AWS_109:KMS key policies require '*' as resource; the policy is attached to the key and scoped to it by design.
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
    sid    = "AllowSNSToUseKey"
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
      identifiers = ["sns.amazonaws.com"]
    }

    condition {
      test     = "StringEquals"
      variable = "aws:SourceAccount"
      values   = [data.aws_caller_identity.current.account_id]
    }
  }
}

resource "aws_kms_key" "sns" {
  count                   = var.kms_master_key_id == null ? 1 : 0
  description             = "KMS key for SNS topic encryption (${var.name})"
  deletion_window_in_days = 7
  enable_key_rotation     = true
  policy                  = data.aws_iam_policy_document.sns_kms_policy.json
  tags                    = var.tags
}

resource "aws_kms_alias" "sns" {
  count         = var.kms_master_key_id == null ? 1 : 0
  name          = "alias/${var.name}-sns"
  target_key_id = aws_kms_key.sns[0].key_id
}

resource "aws_sns_topic" "this" {
  name                        = var.name
  fifo_topic                  = var.fifo_topic
  content_based_deduplication = var.fifo_topic ? var.content_based_deduplication : null
  display_name                = var.display_name != "" ? var.display_name : null
  # Trivy AWS-0136: enforce customer-managed CMK.
  kms_master_key_id = local.sns_kms_key_id
  policy            = var.policy
  delivery_policy   = var.delivery_policy

  tags = var.tags
}

resource "aws_sns_topic_subscription" "this" {
  for_each = var.subscriptions

  topic_arn                       = aws_sns_topic.this.arn
  protocol                        = each.value.protocol
  endpoint                        = each.value.endpoint
  raw_message_delivery            = each.value.raw_message_delivery
  filter_policy                   = each.value.filter_policy
  filter_policy_scope             = each.value.filter_policy != null ? each.value.filter_policy_scope : null
  confirmation_timeout_in_minutes = each.value.confirmation_timeout_in_minutes
  endpoint_auto_confirms          = each.value.endpoint_auto_confirms
}
