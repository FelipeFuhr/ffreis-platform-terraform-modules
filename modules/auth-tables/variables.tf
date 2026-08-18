variable "name" {
  description = "Base name for the auth tables. Each table name is derived by appending a fixed suffix: '<name>-mfa-secrets', '<name>-recovery-codes', '<name>-pending-auth', '<name>-verification-tokens'. Compose the product and environment into this value, e.g. 'petlook-auth-dev'."
  type        = string
}

variable "tags" {
  description = "Tags applied to all tables (use the tagging module output; set a per-product CostCenter)."
  type        = map(string)
  default     = {}
}

# ---------------------------------------------------------------------------
# MFA (TOTP) secrets — durable
# ---------------------------------------------------------------------------

variable "create_mfa_secrets_table" {
  description = "Create the MFA (TOTP) secrets table. Disable if this product does not offer two-factor authentication."
  type        = bool
  default     = true
}

variable "mfa_secrets_deletion_protection_enabled" {
  description = "DynamoDB deletion protection on the MFA secrets table. Defaults to true: losing this table locks every enrolled user out of their own account."
  type        = bool
  default     = true
}

variable "mfa_secrets_prevent_destroy" {
  description = "Block terraform destroy/replace of the MFA secrets table with a lifecycle guard. Defaults to true for the same reason as deletion protection. To intentionally destroy the table, set this to false and apply before running destroy."
  type        = bool
  default     = true
}

# ---------------------------------------------------------------------------
# Recovery codes — durable
# ---------------------------------------------------------------------------

variable "create_recovery_codes_table" {
  description = "Create the MFA recovery codes table. Disable if this product does not offer two-factor authentication."
  type        = bool
  default     = true
}

variable "recovery_codes_deletion_protection_enabled" {
  description = "DynamoDB deletion protection on the recovery codes table. Defaults to true: losing this table locks every enrolled user out of their own account."
  type        = bool
  default     = true
}

variable "recovery_codes_prevent_destroy" {
  description = "Block terraform destroy/replace of the recovery codes table with a lifecycle guard. Defaults to true for the same reason as deletion protection. To intentionally destroy the table, set this to false and apply before running destroy."
  type        = bool
  default     = true
}

# ---------------------------------------------------------------------------
# Pending auth — ephemeral
# ---------------------------------------------------------------------------

variable "create_pending_auth_table" {
  description = "Create the pending (partial) auth session table, used to hold a login between the primary factor succeeding and MFA confirmation."
  type        = bool
  default     = true
}

variable "pending_auth_deletion_protection_enabled" {
  description = "DynamoDB deletion protection on the pending auth table. Defaults to false: the table is ephemeral and TTL'd, so losing it only breaks logins that are already in flight, which self-heal on retry."
  type        = bool
  default     = false
}

variable "pending_auth_prevent_destroy" {
  description = "Block terraform destroy/replace of the pending auth table with a lifecycle guard. Defaults to false for the same reason as deletion protection."
  type        = bool
  default     = false
}

# ---------------------------------------------------------------------------
# Verification tokens — ephemeral
# ---------------------------------------------------------------------------

variable "create_verification_tokens_table" {
  description = "Create the generic single-use verification tokens table (email verification, password reset, invite links, and similar flows)."
  type        = bool
  default     = true
}

variable "verification_tokens_deletion_protection_enabled" {
  description = "DynamoDB deletion protection on the verification tokens table. Defaults to false: the table is ephemeral and TTL'd, so losing it only breaks verification flows that are already in flight, which self-heal on retry."
  type        = bool
  default     = false
}

variable "verification_tokens_prevent_destroy" {
  description = "Block terraform destroy/replace of the verification tokens table with a lifecycle guard. Defaults to false for the same reason as deletion protection."
  type        = bool
  default     = false
}
