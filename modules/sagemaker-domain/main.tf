# ---------------------------------------------------------------------------
# SageMaker execution role (shared domain-level role when callers don't BYO)
# Note: The execution_role in default_user_settings is caller-supplied.
# This module creates the domain and user profiles; IAM roles should be
# created separately using the iam-role module.
# ---------------------------------------------------------------------------

resource "aws_sagemaker_domain" "this" {
  domain_name             = var.domain_name
  auth_mode               = var.auth_mode
  vpc_id                  = var.vpc_id
  subnet_ids              = var.subnet_ids
  app_network_access_type = var.app_network_access_type
  kms_key_id              = var.kms_key_id

  default_user_settings {
    execution_role  = var.default_user_settings.execution_role
    security_groups = var.default_user_settings.security_groups

    dynamic "sharing_settings" {
      for_each = var.default_user_settings.sharing_settings != null ? [var.default_user_settings.sharing_settings] : []
      content {
        notebook_output_option = sharing_settings.value.notebook_output_option
        s3_kms_key_id          = sharing_settings.value.s3_kms_key_id
        s3_output_path         = sharing_settings.value.s3_output_path
      }
    }
  }

  tags = var.tags
}

resource "aws_sagemaker_user_profile" "this" {
  for_each = var.user_profiles

  domain_id         = aws_sagemaker_domain.this.id
  user_profile_name = each.key

  user_settings {
    execution_role  = coalesce(each.value.execution_role, var.default_user_settings.execution_role)
    security_groups = each.value.security_groups
  }

  tags = merge(var.tags, each.value.tags)
}
