###############################################################################
# auth-tables — DynamoDB storage + least-privilege IAM policy documents for a
# self-hosted authentication stack: TOTP two-factor, recovery codes, partial
# ("pending") auth sessions, and generic single-use verification tokens.
#
# Product-agnostic: every table name derives from a single `name` prefix (the
# caller composes product + environment into it, e.g. "petlook-auth-dev").
# Each table is independently toggleable — a product that only needs
# verification tokens (email confirmation, password reset) can disable the
# other three.
#
# $0 fixed cost: PAY_PER_REQUEST on all four tables, and every table's SSE
# block sets kms_key_arn = null (never overridable) so encryption always
# resolves to the AWS-OWNED key — no monthly key fee and no per-request KMS
# API charges at all. This deliberately never offers the AWS-MANAGED alias
# (alias/aws/dynamodb) as an option: that alias has no monthly fee either,
# but DOES bill standard per-request KMS API charges beyond the free tier,
# and it is easy to reach for by name-confusion with "AWS-owned." A
# customer-managed CMK (aws_kms_key, ~$1/mo) is out of scope entirely.
#
# Point-in-time recovery is on for the two DURABLE tables (MFA secrets,
# recovery codes — losing them locks every enrolled user out of their own
# account) and off for the two EPHEMERAL, TTL'd tables (pending auth,
# verification tokens — losing an in-flight row just makes the user retry,
# which self-heals).
#
# This module owns ONLY the tables + IAM policy-JSON outputs (ports-and-
# adapters: callers wire their own Lambdas/roles and attach the policy that
# matches what that Lambda actually does — a token-verify Lambda never gets
# write access it doesn't need).
###############################################################################

locals {
  mfa_secrets_table_name         = "${var.name}-mfa-secrets"
  recovery_codes_table_name      = "${var.name}-recovery-codes"
  pending_auth_table_name        = "${var.name}-pending-auth"
  verification_tokens_table_name = "${var.name}-verification-tokens"
}

# ---------------------------------------------------------------------------
# MFA (TOTP) secrets — DURABLE. HASH UserId. No TTL: enrollment persists
# until the user (or an admin) explicitly disables 2FA.
# ---------------------------------------------------------------------------
resource "aws_dynamodb_table" "mfa_secrets" {
  count = var.create_mfa_secrets_table ? 1 : 0

  name                        = local.mfa_secrets_table_name
  billing_mode                = "PAY_PER_REQUEST"
  hash_key                    = "UserId"
  deletion_protection_enabled = var.mfa_secrets_deletion_protection_enabled

  attribute {
    name = "UserId"
    type = "S"
  }

  # Durable table — 35-day recovery window for accidental writes/deletes.
  point_in_time_recovery {
    enabled = true
  }

  # AWS-owned key — see the module header for why kms_key_arn is a literal
  # null rather than a variable.
  server_side_encryption {
    enabled     = true
    kms_key_arn = null
  }

  tags = var.tags
}

resource "terraform_data" "mfa_secrets_destroy_guard" {
  count = var.create_mfa_secrets_table && var.mfa_secrets_prevent_destroy ? 1 : 0
  lifecycle {
    prevent_destroy = true
  }
}

# ---------------------------------------------------------------------------
# Recovery codes — DURABLE. HASH UserId + RANGE CodeHash (one item per code;
# store only a hash of the code, never the plaintext). No TTL: codes remain
# valid until consumed or the user regenerates their set.
# ---------------------------------------------------------------------------
resource "aws_dynamodb_table" "recovery_codes" {
  count = var.create_recovery_codes_table ? 1 : 0

  name                        = local.recovery_codes_table_name
  billing_mode                = "PAY_PER_REQUEST"
  hash_key                    = "UserId"
  range_key                   = "CodeHash"
  deletion_protection_enabled = var.recovery_codes_deletion_protection_enabled

  attribute {
    name = "UserId"
    type = "S"
  }

  attribute {
    name = "CodeHash"
    type = "S"
  }

  point_in_time_recovery {
    enabled = true
  }

  # AWS-owned key — see the module header for why kms_key_arn is a literal
  # null rather than a variable.
  server_side_encryption {
    enabled     = true
    kms_key_arn = null
  }

  tags = var.tags
}

resource "terraform_data" "recovery_codes_destroy_guard" {
  count = var.create_recovery_codes_table && var.recovery_codes_prevent_destroy ? 1 : 0
  lifecycle {
    prevent_destroy = true
  }
}

# ---------------------------------------------------------------------------
# Pending auth — EPHEMERAL. HASH PendingTokenHash, TTL ExpiresAt. Holds a
# partial login between the primary factor succeeding and MFA confirmation.
# Losing an in-flight row just makes the user sign in again.
# ---------------------------------------------------------------------------
resource "aws_dynamodb_table" "pending_auth" {
  count = var.create_pending_auth_table ? 1 : 0

  name                        = local.pending_auth_table_name
  billing_mode                = "PAY_PER_REQUEST"
  hash_key                    = "PendingTokenHash"
  deletion_protection_enabled = var.pending_auth_deletion_protection_enabled

  attribute {
    name = "PendingTokenHash"
    type = "S"
  }

  ttl {
    attribute_name = "ExpiresAt"
    enabled        = true
  }

  #checkov:skip=CKV_AWS_28:Ephemeral TTL'd table — rows self-expire within minutes; a row lost between backups just makes the user sign in again, so PITR adds cost with no operational benefit here.
  point_in_time_recovery {
    enabled = false
  }

  # AWS-owned key — see the module header for why kms_key_arn is a literal
  # null rather than a variable.
  server_side_encryption {
    enabled     = true
    kms_key_arn = null
  }

  tags = var.tags
}

resource "terraform_data" "pending_auth_destroy_guard" {
  count = var.create_pending_auth_table && var.pending_auth_prevent_destroy ? 1 : 0
  lifecycle {
    prevent_destroy = true
  }
}

# ---------------------------------------------------------------------------
# Verification tokens — EPHEMERAL. HASH Token, TTL ExpiresAt. Generic
# single-use tokens: email verification, password reset, invite links, and
# similar flows. Losing an in-flight row just makes the user request a new
# link.
# ---------------------------------------------------------------------------
resource "aws_dynamodb_table" "verification_tokens" {
  count = var.create_verification_tokens_table ? 1 : 0

  name                        = local.verification_tokens_table_name
  billing_mode                = "PAY_PER_REQUEST"
  hash_key                    = "Token"
  deletion_protection_enabled = var.verification_tokens_deletion_protection_enabled

  attribute {
    name = "Token"
    type = "S"
  }

  ttl {
    attribute_name = "ExpiresAt"
    enabled        = true
  }

  #checkov:skip=CKV_AWS_28:Ephemeral TTL'd table — rows self-expire within minutes; a row lost between backups just makes the user request a new link, so PITR adds cost with no operational benefit here.
  point_in_time_recovery {
    enabled = false
  }

  # AWS-owned key — see the module header for why kms_key_arn is a literal
  # null rather than a variable.
  server_side_encryption {
    enabled     = true
    kms_key_arn = null
  }

  tags = var.tags
}

resource "terraform_data" "verification_tokens_destroy_guard" {
  count = var.create_verification_tokens_table && var.verification_tokens_prevent_destroy ? 1 : 0
  lifecycle {
    prevent_destroy = true
  }
}

###############################################################################
# IAM policy documents — least privilege, one pair per table, so a Lambda
# that only verifies/consumes never gets write access it doesn't need.
###############################################################################

# --- MFA secrets ---

# Enroll / disable: write a new secret on enroll, remove it on disable.
data "aws_iam_policy_document" "mfa_secrets_enroll" {
  count = var.create_mfa_secrets_table ? 1 : 0

  statement {
    sid       = "EnrollMfaSecret"
    effect    = "Allow"
    actions   = ["dynamodb:PutItem", "dynamodb:DeleteItem"]
    resources = [aws_dynamodb_table.mfa_secrets[0].arn]
  }
}

# Verify: read the secret to compute the expected TOTP code, then an atomic
# conditional UpdateItem for the replay guard (reject a re-used code) and the
# failure counter (lock out after N bad attempts).
data "aws_iam_policy_document" "mfa_secrets_verify" {
  count = var.create_mfa_secrets_table ? 1 : 0

  statement {
    sid       = "VerifyMfaSecret"
    effect    = "Allow"
    actions   = ["dynamodb:GetItem", "dynamodb:UpdateItem"]
    resources = [aws_dynamodb_table.mfa_secrets[0].arn]
  }
}

# --- Recovery codes ---

# Consume one code. DeleteItem alone — the item's attributes aren't needed
# after redemption, so no GetItem is required.
data "aws_iam_policy_document" "recovery_codes_consume" {
  count = var.create_recovery_codes_table ? 1 : 0

  statement {
    sid       = "ConsumeRecoveryCode"
    effect    = "Allow"
    actions   = ["dynamodb:DeleteItem"]
    resources = [aws_dynamodb_table.recovery_codes[0].arn]
  }
}

# Regenerate the set: Query the user's existing codes, then a single
# BatchWriteItem to delete the old set and put the new one. BatchWriteItem is
# authorized as its own action — it does not also require PutItem/DeleteItem.
data "aws_iam_policy_document" "recovery_codes_regenerate" {
  count = var.create_recovery_codes_table ? 1 : 0

  statement {
    sid       = "RegenerateRecoveryCodes"
    effect    = "Allow"
    actions   = ["dynamodb:Query", "dynamodb:BatchWriteItem"]
    resources = [aws_dynamodb_table.recovery_codes[0].arn]
  }
}

# --- Pending auth ---

# Create a pending session after the primary factor succeeds.
data "aws_iam_policy_document" "pending_auth_create" {
  count = var.create_pending_auth_table ? 1 : 0

  statement {
    sid       = "CreatePendingAuth"
    effect    = "Allow"
    actions   = ["dynamodb:PutItem"]
    resources = [aws_dynamodb_table.pending_auth[0].arn]
  }
}

# Consume (complete login on MFA confirmation). DeleteItem with
# ReturnValues = ALL_OLD returns the deleted item's attributes in the same
# call, so no separate GetItem is required.
data "aws_iam_policy_document" "pending_auth_consume" {
  count = var.create_pending_auth_table ? 1 : 0

  statement {
    sid       = "ConsumePendingAuth"
    effect    = "Allow"
    actions   = ["dynamodb:DeleteItem"]
    resources = [aws_dynamodb_table.pending_auth[0].arn]
  }
}

# --- Verification tokens ---

# Issue a new single-use token.
data "aws_iam_policy_document" "verification_tokens_issue" {
  count = var.create_verification_tokens_table ? 1 : 0

  statement {
    sid       = "IssueVerificationToken"
    effect    = "Allow"
    actions   = ["dynamodb:PutItem"]
    resources = [aws_dynamodb_table.verification_tokens[0].arn]
  }
}

# Consume a token. DeleteItem with ReturnValues = ALL_OLD returns the
# deleted item's attributes in the same call — not GetItem + DeleteItem.
data "aws_iam_policy_document" "verification_tokens_consume" {
  count = var.create_verification_tokens_table ? 1 : 0

  statement {
    sid       = "ConsumeVerificationToken"
    effect    = "Allow"
    actions   = ["dynamodb:DeleteItem"]
    resources = [aws_dynamodb_table.verification_tokens[0].arn]
  }
}
