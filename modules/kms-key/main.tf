data "aws_caller_identity" "current" {}

# ---------------------------------------------------------------------------
# KMS key
# ---------------------------------------------------------------------------
resource "aws_kms_key" "this" {
  description             = var.description
  deletion_window_in_days = var.deletion_window_in_days
  # Enforce annual rotation for all customer managed keys.
  enable_key_rotation = true
  multi_region        = var.multi_region
  policy              = local.effective_policy

  tags = var.tags
}

resource "aws_kms_alias" "this" {
  name          = "alias/${var.alias}"
  target_key_id = aws_kms_key.this.key_id
}

# ---------------------------------------------------------------------------
# Default key policy (used when caller does not supply one)
# Grants account root full access; grants additional_principals Decrypt
# and GenerateDataKey so they can use the key for SSE workloads.
# ---------------------------------------------------------------------------
data "aws_iam_policy_document" "default" {
  statement {
    sid     = "EnableRootAccess"
    effect  = local.iam_effect_allow
    actions = ["kms:*"]

    principals {
      type        = local.iam_principal_type_aws
      identifiers = ["arn:aws:iam::${data.aws_caller_identity.current.account_id}:root"]
    }
    resources = [local.iam_resource_all]
  }

  dynamic "statement" {
    for_each = length(var.additional_principals) > 0 ? [1] : []
    content {
      sid    = "AllowServiceUse"
      effect = local.iam_effect_allow
      actions = [
        "kms:Decrypt",
        "kms:GenerateDataKey",
        "kms:GenerateDataKeyWithoutPlaintext",
        "kms:DescribeKey",
        "kms:ReEncrypt*",
      ]
      principals {
        type        = local.iam_principal_type_aws
        identifiers = var.additional_principals
      }
      resources = [local.iam_resource_all]
    }
  }
}

locals {
  effective_policy = var.policy != null ? var.policy : data.aws_iam_policy_document.default.json

  iam_effect_allow       = "Allow"
  iam_principal_type_aws = "AWS"
  iam_resource_all       = "*"
}
