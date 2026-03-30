resource "aws_ecs_cluster" "this" {
  name = var.name

  setting {
    name  = "containerInsights"
    value = var.enable_container_insights ? "enabled" : "disabled"
  }

  configuration {
    execute_command_configuration {
      kms_key_id = local.exec_kms_key_arn
      logging    = "OVERRIDE"

      log_configuration {
        cloud_watch_encryption_enabled = true
        cloud_watch_log_group_name     = aws_cloudwatch_log_group.exec.name
        s3_bucket_name                 = var.execute_command_s3_bucket
        s3_key_prefix                  = var.execute_command_s3_bucket != null ? "ecs-exec" : null
      }
    }
  }

  tags = var.tags

  depends_on = [aws_cloudwatch_log_group.exec]
}

resource "aws_ecs_cluster_capacity_providers" "this" {
  cluster_name       = aws_ecs_cluster.this.name
  capacity_providers = var.capacity_providers

  dynamic "default_capacity_provider_strategy" {
    for_each = var.default_capacity_provider_strategy
    content {
      capacity_provider = default_capacity_provider_strategy.value.capacity_provider
      weight            = default_capacity_provider_strategy.value.weight
      base              = default_capacity_provider_strategy.value.base
    }
  }
}

locals {
  exec_log_group_name = var.execute_command_log_group_name != null ? var.execute_command_log_group_name : "/ecs/exec/${var.name}"
  exec_kms_key_arn    = var.execute_command_kms_key_arn != null ? var.execute_command_kms_key_arn : aws_kms_key.exec[0].arn
}

data "aws_caller_identity" "current" {}
data "aws_partition" "current" {}
data "aws_region" "current" {}

data "aws_iam_policy_document" "exec_kms_policy" {
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
    sid    = "AllowCloudWatchLogsToUseKey"
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
      identifiers = ["logs.${data.aws_region.current.name}.amazonaws.com"]
    }

    condition {
      test     = "StringEquals"
      variable = "aws:SourceAccount"
      values   = [data.aws_caller_identity.current.account_id]
    }
  }
}

resource "aws_kms_key" "exec" {
  count                   = var.execute_command_kms_key_arn == null ? 1 : 0
  description             = "KMS key for ECS Exec audit logs (${var.name})"
  deletion_window_in_days = 7
  enable_key_rotation     = true
  policy                  = data.aws_iam_policy_document.exec_kms_policy.json
  tags                    = var.tags
}

resource "aws_kms_alias" "exec" {
  count         = var.execute_command_kms_key_arn == null ? 1 : 0
  name          = "alias/${var.name}-ecs-exec"
  target_key_id = aws_kms_key.exec[0].key_id
}

resource "aws_cloudwatch_log_group" "exec" {
  name              = local.exec_log_group_name
  retention_in_days = 365
  kms_key_id        = local.exec_kms_key_arn
  tags              = var.tags
}
