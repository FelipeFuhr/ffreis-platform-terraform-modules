# --- MFA secrets ---

output "mfa_secrets_table_name" {
  description = "MFA secrets table name (null if create_mfa_secrets_table = false)."
  value       = var.create_mfa_secrets_table ? aws_dynamodb_table.mfa_secrets[0].id : null
}

output "mfa_secrets_table_arn" {
  description = "MFA secrets table ARN (null if create_mfa_secrets_table = false)."
  value       = var.create_mfa_secrets_table ? aws_dynamodb_table.mfa_secrets[0].arn : null
}

output "mfa_secrets_enroll_policy_json" {
  description = "dynamodb:PutItem/DeleteItem on the MFA secrets table. Attach to the role that enrolls or disables TOTP. Null if create_mfa_secrets_table = false."
  value       = var.create_mfa_secrets_table ? data.aws_iam_policy_document.mfa_secrets_enroll[0].json : null
}

output "mfa_secrets_verify_policy_json" {
  description = "dynamodb:GetItem/UpdateItem on the MFA secrets table. Attach to the role that verifies a TOTP code: read the secret, then the atomic replay-guard/failure-counter write. Null if create_mfa_secrets_table = false."
  value       = var.create_mfa_secrets_table ? data.aws_iam_policy_document.mfa_secrets_verify[0].json : null
}

# --- Recovery codes ---

output "recovery_codes_table_name" {
  description = "Recovery codes table name (null if create_recovery_codes_table = false)."
  value       = var.create_recovery_codes_table ? aws_dynamodb_table.recovery_codes[0].id : null
}

output "recovery_codes_table_arn" {
  description = "Recovery codes table ARN (null if create_recovery_codes_table = false)."
  value       = var.create_recovery_codes_table ? aws_dynamodb_table.recovery_codes[0].arn : null
}

output "recovery_codes_consume_policy_json" {
  description = "dynamodb:DeleteItem on the recovery codes table. Attach to the role that redeems one recovery code. Null if create_recovery_codes_table = false."
  value       = var.create_recovery_codes_table ? data.aws_iam_policy_document.recovery_codes_consume[0].json : null
}

output "recovery_codes_regenerate_policy_json" {
  description = "dynamodb:Query/BatchWriteItem on the recovery codes table. Attach to the role that regenerates a user's recovery code set. Null if create_recovery_codes_table = false."
  value       = var.create_recovery_codes_table ? data.aws_iam_policy_document.recovery_codes_regenerate[0].json : null
}

# --- Pending auth ---

output "pending_auth_table_name" {
  description = "Pending auth table name (null if create_pending_auth_table = false)."
  value       = var.create_pending_auth_table ? aws_dynamodb_table.pending_auth[0].id : null
}

output "pending_auth_table_arn" {
  description = "Pending auth table ARN (null if create_pending_auth_table = false)."
  value       = var.create_pending_auth_table ? aws_dynamodb_table.pending_auth[0].arn : null
}

output "pending_auth_create_policy_json" {
  description = "dynamodb:PutItem on the pending auth table. Attach to the role that creates a pending session after the primary factor succeeds. Null if create_pending_auth_table = false."
  value       = var.create_pending_auth_table ? data.aws_iam_policy_document.pending_auth_create[0].json : null
}

output "pending_auth_consume_policy_json" {
  description = "dynamodb:DeleteItem on the pending auth table. Attach to the role that completes a login by consuming the pending session on MFA confirmation. Null if create_pending_auth_table = false."
  value       = var.create_pending_auth_table ? data.aws_iam_policy_document.pending_auth_consume[0].json : null
}

# --- Verification tokens ---

output "verification_tokens_table_name" {
  description = "Verification tokens table name (null if create_verification_tokens_table = false)."
  value       = var.create_verification_tokens_table ? aws_dynamodb_table.verification_tokens[0].id : null
}

output "verification_tokens_table_arn" {
  description = "Verification tokens table ARN (null if create_verification_tokens_table = false)."
  value       = var.create_verification_tokens_table ? aws_dynamodb_table.verification_tokens[0].arn : null
}

output "verification_tokens_issue_policy_json" {
  description = "dynamodb:PutItem on the verification tokens table. Attach to the role that issues a single-use token. Null if create_verification_tokens_table = false."
  value       = var.create_verification_tokens_table ? data.aws_iam_policy_document.verification_tokens_issue[0].json : null
}

output "verification_tokens_consume_policy_json" {
  description = "dynamodb:DeleteItem on the verification tokens table. Attach to the role that consumes a single-use token. Null if create_verification_tokens_table = false."
  value       = var.create_verification_tokens_table ? data.aws_iam_policy_document.verification_tokens_consume[0].json : null
}
