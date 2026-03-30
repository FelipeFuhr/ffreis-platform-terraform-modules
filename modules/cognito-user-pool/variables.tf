variable "name" {
  description = "Cognito user pool name."
  type        = string
}

variable "alias_attributes" {
  description = "Attributes users can sign in with: 'email', 'phone_number', 'preferred_username'."
  type        = list(string)
  default     = ["email"]
}

variable "auto_verified_attributes" {
  description = "Attributes auto-verified after sign-up: 'email', 'phone_number'."
  type        = list(string)
  default     = ["email"]
}

variable "mfa_configuration" {
  description = "MFA requirement: 'OFF', 'OPTIONAL', or 'ON'."
  type        = string
  default     = "OPTIONAL"

  validation {
    condition     = contains(["OFF", "OPTIONAL", "ON"], var.mfa_configuration)
    error_message = "mfa_configuration must be 'OFF', 'OPTIONAL', or 'ON'."
  }
}

variable "software_token_mfa_enabled" {
  description = "Allow TOTP authenticator apps as an MFA method."
  type        = bool
  default     = true
}

variable "password_policy" {
  description = "Password policy settings."
  type = object({
    minimum_length                   = optional(number, 12)
    require_lowercase                = optional(bool, true)
    require_uppercase                = optional(bool, true)
    require_numbers                  = optional(bool, true)
    require_symbols                  = optional(bool, true)
    temporary_password_validity_days = optional(number, 7)
  })
  default = {}
}

variable "deletion_protection" {
  description = "Prevent the user pool from being deleted: 'ACTIVE' or 'INACTIVE'."
  type        = string
  default     = "ACTIVE"

  validation {
    condition     = contains(["ACTIVE", "INACTIVE"], var.deletion_protection)
    error_message = "deletion_protection must be 'ACTIVE' or 'INACTIVE'."
  }
}

variable "advanced_security_mode" {
  description = "Advanced security: 'OFF', 'AUDIT', or 'ENFORCED'."
  type        = string
  default     = "ENFORCED"

  validation {
    condition     = contains(["OFF", "AUDIT", "ENFORCED"], var.advanced_security_mode)
    error_message = "advanced_security_mode must be OFF, AUDIT, or ENFORCED."
  }
}

variable "schema_attributes" {
  description = "Custom user pool schema attributes."
  type = list(object({
    name                = string
    attribute_data_type = string # String | Number | DateTime | Boolean
    required            = optional(bool, false)
    mutable             = optional(bool, true)
    string_attribute_constraints = optional(object({
      min_length = optional(string, "0")
      max_length = optional(string, "2048")
    }), null)
  }))
  default = []
}

variable "app_clients" {
  description = "Map of app client name → configuration."
  type = map(object({
    generate_secret                      = optional(bool, false)
    allowed_oauth_flows                  = optional(list(string), ["code"])
    allowed_oauth_flows_user_pool_client = optional(bool, true)
    allowed_oauth_scopes                 = optional(list(string), ["openid", "email", "profile"])
    callback_urls                        = optional(list(string), [])
    logout_urls                          = optional(list(string), [])
    supported_identity_providers         = optional(list(string), ["COGNITO"])
    access_token_validity                = optional(number, 60) # minutes
    id_token_validity                    = optional(number, 60) # minutes
    refresh_token_validity               = optional(number, 30) # days
    enable_token_revocation              = optional(bool, true)
    prevent_user_existence_errors        = optional(string, "ENABLED")
    explicit_auth_flows = optional(list(string), [
      "ALLOW_REFRESH_TOKEN_AUTH",
      "ALLOW_USER_SRP_AUTH",
    ])
  }))
  default = {}
}

variable "email_from_address" {
  description = "SES verified email address to use as the FROM address. null = Cognito default."
  type        = string
  default     = null
}

variable "email_source_arn" {
  description = "SES verified identity ARN for sending emails. Required with email_from_address."
  type        = string
  default     = null
}

variable "tags" {
  description = "Tags applied to all resources."
  type        = map(string)
  default     = {}
}
