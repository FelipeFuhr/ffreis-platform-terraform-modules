locals {
  dlq_name = var.fifo_queue ? "${trimsuffix(var.name, ".fifo")}-dlq.fifo" : "${var.name}-dlq"

  sqs_kms_key_id = var.kms_master_key_id != null ? var.kms_master_key_id : aws_kms_key.sqs[0].arn
}

data "aws_caller_identity" "current" {}
data "aws_partition" "current" {}

data "aws_iam_policy_document" "sqs_kms_policy" {
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
    sid    = "AllowSQSToUseKey"
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
      identifiers = ["sqs.amazonaws.com"]
    }

    condition {
      test     = "StringEquals"
      variable = "aws:SourceAccount"
      values   = [data.aws_caller_identity.current.account_id]
    }
  }
}

resource "aws_kms_key" "sqs" {
  count                   = var.kms_master_key_id == null ? 1 : 0
  description             = "KMS key for SQS queue encryption (${var.name})"
  deletion_window_in_days = 7
  enable_key_rotation     = true
  policy                  = data.aws_iam_policy_document.sqs_kms_policy.json
  tags                    = var.tags
}

resource "aws_kms_alias" "sqs" {
  count         = var.kms_master_key_id == null ? 1 : 0
  name          = "alias/${trimsuffix(var.name, ".fifo")}-sqs"
  target_key_id = aws_kms_key.sqs[0].key_id
}

# ---------------------------------------------------------------------------
# Dead-Letter Queue
# ---------------------------------------------------------------------------
resource "aws_sqs_queue" "dlq" {
  count = var.create_dlq ? 1 : 0

  name                        = local.dlq_name
  fifo_queue                  = var.fifo_queue
  content_based_deduplication = var.fifo_queue ? var.content_based_deduplication : null
  message_retention_seconds   = var.dlq_message_retention_seconds
  # Trivy AWS-0135: enforce customer-managed CMK.
  kms_master_key_id                 = local.sqs_kms_key_id
  kms_data_key_reuse_period_seconds = var.kms_data_key_reuse_period_seconds

  tags = merge(var.tags, { Role = "dlq" })
}

# ---------------------------------------------------------------------------
# Main queue
# ---------------------------------------------------------------------------
resource "aws_sqs_queue" "this" {
  name                        = var.name
  fifo_queue                  = var.fifo_queue
  content_based_deduplication = var.fifo_queue ? var.content_based_deduplication : null
  visibility_timeout_seconds  = var.visibility_timeout_seconds
  message_retention_seconds   = var.message_retention_seconds
  max_message_size            = var.max_message_size
  delay_seconds               = var.delay_seconds
  receive_wait_time_seconds   = var.receive_wait_time_seconds
  # Trivy AWS-0135: enforce customer-managed CMK.
  kms_master_key_id                 = local.sqs_kms_key_id
  kms_data_key_reuse_period_seconds = var.kms_data_key_reuse_period_seconds

  redrive_policy = var.create_dlq ? jsonencode({
    deadLetterTargetArn = aws_sqs_queue.dlq[0].arn
    maxReceiveCount     = var.max_receive_count
  }) : null

  tags = var.tags
}

resource "aws_sqs_queue_policy" "this" {
  count     = var.policy != null ? 1 : 0
  queue_url = aws_sqs_queue.this.id
  policy    = var.policy
}
