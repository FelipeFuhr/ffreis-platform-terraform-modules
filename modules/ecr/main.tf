locals {
  # Build a default lifecycle policy when the caller doesn't supply one.
  default_lifecycle_rules = compact([
    var.untagged_image_expiry_days > 0 ? jsonencode({
      rulePriority = 1
      description  = "Expire untagged images after ${var.untagged_image_expiry_days} days"
      selection = {
        tagStatus   = "untagged"
        countType   = "sinceImagePushed"
        countUnit   = "days"
        countNumber = var.untagged_image_expiry_days
      }
      action = { type = "expire" }
    }) : null,
    var.keep_image_count > 0 ? jsonencode({
      rulePriority = 2
      description  = "Keep only the ${var.keep_image_count} most recent tagged images"
      selection = {
        tagStatus     = "tagged"
        tagPrefixList = ["v", ""]
        countType     = "imageCountMoreThan"
        countNumber   = var.keep_image_count
      }
      action = { type = "expire" }
    }) : null,
  ])

  lifecycle_policy = var.lifecycle_policy != null ? var.lifecycle_policy : (
    length(local.default_lifecycle_rules) > 0 ? jsonencode({ rules = [
      for rule in local.default_lifecycle_rules : jsondecode(rule)
    ] }) : null
  )
}

data "aws_caller_identity" "current" {}
data "aws_partition" "current" {}

resource "aws_ecr_repository" "this" {
  name                 = var.name
  image_tag_mutability = var.image_tag_mutability
  force_delete         = var.force_delete

  image_scanning_configuration {
    scan_on_push = var.scan_on_push
  }

  # Checkov CKV_AWS_136: enforce KMS encryption.
  encryption_configuration {
    encryption_type = var.encryption_type
    kms_key         = var.kms_key_arn != null ? var.kms_key_arn : aws_kms_key.ecr[0].arn
  }

  tags = var.tags
}

data "aws_iam_policy_document" "ecr_kms_policy" {
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
    sid    = "AllowECRToUseKey"
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
      identifiers = ["ecr.amazonaws.com"]
    }

    condition {
      test     = "StringEquals"
      variable = "aws:SourceAccount"
      values   = [data.aws_caller_identity.current.account_id]
    }
  }
}

resource "aws_kms_key" "ecr" {
  count                   = var.kms_key_arn == null ? 1 : 0
  description             = "KMS key for ECR repository encryption (${var.name})"
  deletion_window_in_days = 7
  enable_key_rotation     = true
  policy                  = data.aws_iam_policy_document.ecr_kms_policy.json
  tags                    = var.tags
}

resource "aws_kms_alias" "ecr" {
  count         = var.kms_key_arn == null ? 1 : 0
  name          = "alias/${var.name}-ecr"
  target_key_id = aws_kms_key.ecr[0].key_id
}

resource "aws_ecr_lifecycle_policy" "this" {
  count      = local.lifecycle_policy != null ? 1 : 0
  repository = aws_ecr_repository.this.name
  policy     = local.lifecycle_policy
}

resource "aws_ecr_repository_policy" "this" {
  count      = var.repository_policy != null ? 1 : 0
  repository = aws_ecr_repository.this.name
  policy     = var.repository_policy
}
