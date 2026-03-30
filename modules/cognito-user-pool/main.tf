resource "aws_cognito_user_pool" "this" {
  name                = var.name
  alias_attributes    = var.alias_attributes
  deletion_protection = var.deletion_protection

  auto_verified_attributes = var.auto_verified_attributes
  mfa_configuration        = var.mfa_configuration

  software_token_mfa_configuration {
    enabled = var.software_token_mfa_enabled
  }

  password_policy {
    minimum_length                   = var.password_policy.minimum_length
    require_lowercase                = var.password_policy.require_lowercase
    require_uppercase                = var.password_policy.require_uppercase
    require_numbers                  = var.password_policy.require_numbers
    require_symbols                  = var.password_policy.require_symbols
    temporary_password_validity_days = var.password_policy.temporary_password_validity_days
  }

  user_pool_add_ons {
    advanced_security_mode = var.advanced_security_mode
  }

  dynamic "schema" {
    for_each = var.schema_attributes
    content {
      name                = schema.value.name
      attribute_data_type = schema.value.attribute_data_type
      required            = schema.value.required
      mutable             = schema.value.mutable

      dynamic "string_attribute_constraints" {
        for_each = schema.value.string_attribute_constraints != null ? [schema.value.string_attribute_constraints] : []
        content {
          min_length = string_attribute_constraints.value.min_length
          max_length = string_attribute_constraints.value.max_length
        }
      }
    }
  }

  dynamic "email_configuration" {
    for_each = var.email_from_address != null ? [1] : []
    content {
      email_sending_account = "DEVELOPER"
      from_email_address    = var.email_from_address
      source_arn            = var.email_source_arn
    }
  }

  tags = var.tags
}

# ---------------------------------------------------------------------------
# App clients
# ---------------------------------------------------------------------------
resource "aws_cognito_user_pool_client" "this" {
  for_each = var.app_clients

  user_pool_id = aws_cognito_user_pool.this.id
  name         = each.key

  generate_secret                      = each.value.generate_secret
  allowed_oauth_flows                  = each.value.allowed_oauth_flows
  allowed_oauth_flows_user_pool_client = each.value.allowed_oauth_flows_user_pool_client
  allowed_oauth_scopes                 = each.value.allowed_oauth_scopes
  callback_urls                        = each.value.callback_urls
  logout_urls                          = each.value.logout_urls
  supported_identity_providers         = each.value.supported_identity_providers
  explicit_auth_flows                  = each.value.explicit_auth_flows
  enable_token_revocation              = each.value.enable_token_revocation
  prevent_user_existence_errors        = each.value.prevent_user_existence_errors

  access_token_validity  = each.value.access_token_validity
  id_token_validity      = each.value.id_token_validity
  refresh_token_validity = each.value.refresh_token_validity

  token_validity_units {
    access_token  = "minutes"
    id_token      = "minutes"
    refresh_token = "days"
  }
}

# ---------------------------------------------------------------------------
# User pool domain (needed for hosted UI / OAuth flows)
# ---------------------------------------------------------------------------
resource "aws_cognito_user_pool_domain" "this" {
  count        = length(var.app_clients) > 0 ? 1 : 0
  user_pool_id = aws_cognito_user_pool.this.id
  domain       = replace(lower(var.name), "_", "-")
}
