# auth-tables

DynamoDB storage + least-privilege IAM policy documents for a **self-hosted**
authentication stack: TOTP two-factor, recovery codes, partial ("pending") auth
sessions, and generic single-use verification tokens (email confirmation,
password reset, invite links, and similar flows).

**Product-agnostic.** Every table name derives from one `name` prefix — the
caller composes product + environment into it (e.g. `"petlook-auth-dev"`,
`"flemming-auth-prod"`). Nothing in this module is product-specific.

Not a replacement for `cognito-user-pool` — this module backs a **self-hosted**
credential/session store; reach for `cognito-user-pool` when a managed identity
provider is the right fit instead.

```
                     ┌─────────────────┐
  primary factor OK  │  pending-auth    │  MFA confirmed
  ─────────PutItem──►│  (ephemeral,     │──────DeleteItem─────► session issued
                      │   TTL'd)         │      (ReturnValues=ALL_OLD)
                      └─────────────────┘
                              │ verify code against
                              ▼
                     ┌─────────────────┐        ┌──────────────────┐
                     │  mfa-secrets     │        │  recovery-codes   │
                     │  (durable)       │        │  (durable)        │
                     └─────────────────┘        └──────────────────┘
                     GetItem+UpdateItem            DeleteItem (consume)
                     (verify, replay guard)         Query+BatchWriteItem
                                                     (regenerate)

  ┌────────────────────────┐
  │  verification-tokens    │  generic single-use tokens: email verify,
  │  (ephemeral, TTL'd)     │  password reset, invite links
  └────────────────────────┘
  PutItem (issue) / DeleteItem (consume, ReturnValues=ALL_OLD)
```

Each table is **independently toggleable** (`create_*_table`, all default
`true`) — a product that only needs verification tokens (e.g. just email
confirmation, no 2FA) can disable the other three.

## Durability

| Table | Key schema | TTL | Durability | Why |
|---|---|---|---|---|
| MFA secrets | HASH `UserId` (S) | none | **Durable** — deletion protection + `prevent_destroy` default **true** | Losing it locks every enrolled user out of their own account |
| Recovery codes | HASH `UserId` (S) + RANGE `CodeHash` (S) | none | **Durable** — deletion protection + `prevent_destroy` default **true** | Same reason |
| Pending auth | HASH `PendingTokenHash` (S) | `ExpiresAt` | **Ephemeral** — deletion protection + `prevent_destroy` default **false** | Rows self-expire; losing an in-flight row just makes the user sign in again |
| Verification tokens | HASH `Token` (S) | `ExpiresAt` | **Ephemeral** — deletion protection + `prevent_destroy` default **false** | Rows self-expire; losing an in-flight row just makes the user request a new link |

Point-in-time recovery follows the same durable/ephemeral split (on for MFA
secrets + recovery codes, off for pending auth + verification tokens — a
`#checkov:skip=CKV_AWS_28` on each ephemeral table documents why).

## $0 fixed cost

`PAY_PER_REQUEST` on all four tables, and every table's `server_side_encryption`
block sets `kms_key_arn = null` (not exposed as a variable — this module never
allows overriding it) so encryption always resolves to the **AWS-owned key**:
no monthly key fee, no per-request KMS API charges, doesn't count against KMS
quotas. This is deliberately **not** the AWS-managed alias
(`alias/aws/dynamodb`) — that alias also has no monthly fee, but it does bill
standard per-request KMS API charges beyond the free tier, and it's easy to
reach for by name-confusion with "AWS-owned." A customer-managed CMK
(`aws_kms_key`, ~$1/mo) is out of scope entirely. Point-in-time recovery on the
two durable tables adds a small usage-based cost (proportional to table size),
not a fixed monthly fee.

## Usage

```hcl
module "auth" {
  source = "git::https://github.com/FelipeFuhr/ffreis-platform-terraform-modules.git//modules/auth-tables?ref=v2.9.0"

  name = "petlook-auth-${var.environment}"
  tags = merge(module.tags.tags, { CostCenter = "petlook" })

  # A product with no 2FA would instead set:
  # create_mfa_secrets_table    = false
  # create_recovery_codes_table = false
}

# TOTP enroll/disable Lambda role: attach module.auth.mfa_secrets_enroll_policy_json
# TOTP verify Lambda role:         attach module.auth.mfa_secrets_verify_policy_json
# Recovery-code redeem role:       attach module.auth.recovery_codes_consume_policy_json
# Recovery-code regenerate role:   attach module.auth.recovery_codes_regenerate_policy_json
# Login-step-1 (create pending):   attach module.auth.pending_auth_create_policy_json
# Login-step-2 (confirm MFA):      attach module.auth.pending_auth_consume_policy_json
# Token-issuing role (e.g. signup):attach module.auth.verification_tokens_issue_policy_json
# Token-consuming role (e.g. confirm): attach module.auth.verification_tokens_consume_policy_json
```

## IAM outputs

Each output is scoped to exactly the actions its consumer needs — a Lambda
that only verifies or consumes never gets write access it doesn't need. All
resolve to `null` when the corresponding `create_*_table` is `false`.

| Output | Actions | For |
|---|---|---|
| `mfa_secrets_enroll_policy_json` | `PutItem`, `DeleteItem` | The role that enrolls a new TOTP secret or disables 2FA |
| `mfa_secrets_verify_policy_json` | `GetItem`, `UpdateItem` | The TOTP verify path: read the secret to compute the expected code, then an atomic conditional `UpdateItem` for the replay guard and failure counter |
| `recovery_codes_consume_policy_json` | `DeleteItem` | Redeeming one recovery code — the item's attributes aren't needed after redemption, so no `GetItem` |
| `recovery_codes_regenerate_policy_json` | `Query`, `BatchWriteItem` | Regenerating a user's recovery code set: query the existing codes, then delete-old+put-new in one batch |
| `pending_auth_create_policy_json` | `PutItem` | Creating a pending session after the primary factor succeeds |
| `pending_auth_consume_policy_json` | `DeleteItem` | Completing a login on MFA confirmation — `DeleteItem` with `ReturnValues=ALL_OLD` returns the item in the same call, so no separate `GetItem` |
| `verification_tokens_issue_policy_json` | `PutItem` | Issuing a new single-use token |
| `verification_tokens_consume_policy_json` | `DeleteItem` | Consuming a single-use token — again `ReturnValues=ALL_OLD`, not `GetItem` + `DeleteItem` |

<!-- BEGIN_TF_DOCS -->
## Requirements

| Name | Version |
|------|---------|
| <a name="requirement_terraform"></a> [terraform](#requirement\_terraform) | >= 1.5.0, < 2.0.0 |
| <a name="requirement_aws"></a> [aws](#requirement\_aws) | >= 5.0 |

## Providers

| Name | Version |
|------|---------|
| <a name="provider_aws"></a> [aws](#provider\_aws) | >= 5.0 |
| <a name="provider_terraform"></a> [terraform](#provider\_terraform) | n/a |

## Modules

No modules.

## Resources

| Name | Type |
|------|------|
| [aws_dynamodb_table.mfa_secrets](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/dynamodb_table) | resource |
| [aws_dynamodb_table.pending_auth](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/dynamodb_table) | resource |
| [aws_dynamodb_table.recovery_codes](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/dynamodb_table) | resource |
| [aws_dynamodb_table.verification_tokens](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/dynamodb_table) | resource |
| [terraform_data.mfa_secrets_destroy_guard](https://registry.terraform.io/providers/hashicorp/terraform/latest/docs/resources/data) | resource |
| [terraform_data.pending_auth_destroy_guard](https://registry.terraform.io/providers/hashicorp/terraform/latest/docs/resources/data) | resource |
| [terraform_data.recovery_codes_destroy_guard](https://registry.terraform.io/providers/hashicorp/terraform/latest/docs/resources/data) | resource |
| [terraform_data.verification_tokens_destroy_guard](https://registry.terraform.io/providers/hashicorp/terraform/latest/docs/resources/data) | resource |
| [aws_iam_policy_document.mfa_secrets_enroll](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/data-sources/iam_policy_document) | data source |
| [aws_iam_policy_document.mfa_secrets_verify](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/data-sources/iam_policy_document) | data source |
| [aws_iam_policy_document.pending_auth_consume](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/data-sources/iam_policy_document) | data source |
| [aws_iam_policy_document.pending_auth_create](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/data-sources/iam_policy_document) | data source |
| [aws_iam_policy_document.recovery_codes_consume](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/data-sources/iam_policy_document) | data source |
| [aws_iam_policy_document.recovery_codes_regenerate](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/data-sources/iam_policy_document) | data source |
| [aws_iam_policy_document.verification_tokens_consume](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/data-sources/iam_policy_document) | data source |
| [aws_iam_policy_document.verification_tokens_issue](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/data-sources/iam_policy_document) | data source |

## Inputs

| Name | Description | Type | Default | Required |
|------|-------------|------|---------|:--------:|
| <a name="input_create_mfa_secrets_table"></a> [create\_mfa\_secrets\_table](#input\_create\_mfa\_secrets\_table) | Create the MFA (TOTP) secrets table. Disable if this product does not offer two-factor authentication. | `bool` | `true` | no |
| <a name="input_create_pending_auth_table"></a> [create\_pending\_auth\_table](#input\_create\_pending\_auth\_table) | Create the pending (partial) auth session table, used to hold a login between the primary factor succeeding and MFA confirmation. | `bool` | `true` | no |
| <a name="input_create_recovery_codes_table"></a> [create\_recovery\_codes\_table](#input\_create\_recovery\_codes\_table) | Create the MFA recovery codes table. Disable if this product does not offer two-factor authentication. | `bool` | `true` | no |
| <a name="input_create_verification_tokens_table"></a> [create\_verification\_tokens\_table](#input\_create\_verification\_tokens\_table) | Create the generic single-use verification tokens table (email verification, password reset, invite links, and similar flows). | `bool` | `true` | no |
| <a name="input_mfa_secrets_deletion_protection_enabled"></a> [mfa\_secrets\_deletion\_protection\_enabled](#input\_mfa\_secrets\_deletion\_protection\_enabled) | DynamoDB deletion protection on the MFA secrets table. Defaults to true: losing this table locks every enrolled user out of their own account. | `bool` | `true` | no |
| <a name="input_mfa_secrets_prevent_destroy"></a> [mfa\_secrets\_prevent\_destroy](#input\_mfa\_secrets\_prevent\_destroy) | Block terraform destroy/replace of the MFA secrets table with a lifecycle guard. Defaults to true for the same reason as deletion protection. To intentionally destroy the table, set this to false and apply before running destroy. | `bool` | `true` | no |
| <a name="input_name"></a> [name](#input\_name) | Base name for the auth tables. Each table name is derived by appending a fixed suffix: '<name>-mfa-secrets', '<name>-recovery-codes', '<name>-pending-auth', '<name>-verification-tokens'. Compose the product and environment into this value, e.g. 'petlook-auth-dev'. | `string` | n/a | yes |
| <a name="input_pending_auth_deletion_protection_enabled"></a> [pending\_auth\_deletion\_protection\_enabled](#input\_pending\_auth\_deletion\_protection\_enabled) | DynamoDB deletion protection on the pending auth table. Defaults to false: the table is ephemeral and TTL'd, so losing it only breaks logins that are already in flight, which self-heal on retry. | `bool` | `false` | no |
| <a name="input_pending_auth_prevent_destroy"></a> [pending\_auth\_prevent\_destroy](#input\_pending\_auth\_prevent\_destroy) | Block terraform destroy/replace of the pending auth table with a lifecycle guard. Defaults to false for the same reason as deletion protection. | `bool` | `false` | no |
| <a name="input_recovery_codes_deletion_protection_enabled"></a> [recovery\_codes\_deletion\_protection\_enabled](#input\_recovery\_codes\_deletion\_protection\_enabled) | DynamoDB deletion protection on the recovery codes table. Defaults to true: losing this table locks every enrolled user out of their own account. | `bool` | `true` | no |
| <a name="input_recovery_codes_prevent_destroy"></a> [recovery\_codes\_prevent\_destroy](#input\_recovery\_codes\_prevent\_destroy) | Block terraform destroy/replace of the recovery codes table with a lifecycle guard. Defaults to true for the same reason as deletion protection. To intentionally destroy the table, set this to false and apply before running destroy. | `bool` | `true` | no |
| <a name="input_tags"></a> [tags](#input\_tags) | Tags applied to all tables (use the tagging module output; set a per-product CostCenter). | `map(string)` | `{}` | no |
| <a name="input_verification_tokens_deletion_protection_enabled"></a> [verification\_tokens\_deletion\_protection\_enabled](#input\_verification\_tokens\_deletion\_protection\_enabled) | DynamoDB deletion protection on the verification tokens table. Defaults to false: the table is ephemeral and TTL'd, so losing it only breaks verification flows that are already in flight, which self-heal on retry. | `bool` | `false` | no |
| <a name="input_verification_tokens_prevent_destroy"></a> [verification\_tokens\_prevent\_destroy](#input\_verification\_tokens\_prevent\_destroy) | Block terraform destroy/replace of the verification tokens table with a lifecycle guard. Defaults to false for the same reason as deletion protection. | `bool` | `false` | no |

## Outputs

| Name | Description |
|------|-------------|
| <a name="output_mfa_secrets_enroll_policy_json"></a> [mfa\_secrets\_enroll\_policy\_json](#output\_mfa\_secrets\_enroll\_policy\_json) | dynamodb:PutItem/DeleteItem on the MFA secrets table. Attach to the role that enrolls or disables TOTP. Null if create\_mfa\_secrets\_table = false. |
| <a name="output_mfa_secrets_table_arn"></a> [mfa\_secrets\_table\_arn](#output\_mfa\_secrets\_table\_arn) | MFA secrets table ARN (null if create\_mfa\_secrets\_table = false). |
| <a name="output_mfa_secrets_table_name"></a> [mfa\_secrets\_table\_name](#output\_mfa\_secrets\_table\_name) | MFA secrets table name (null if create\_mfa\_secrets\_table = false). |
| <a name="output_mfa_secrets_verify_policy_json"></a> [mfa\_secrets\_verify\_policy\_json](#output\_mfa\_secrets\_verify\_policy\_json) | dynamodb:GetItem/UpdateItem on the MFA secrets table. Attach to the role that verifies a TOTP code: read the secret, then the atomic replay-guard/failure-counter write. Null if create\_mfa\_secrets\_table = false. |
| <a name="output_pending_auth_consume_policy_json"></a> [pending\_auth\_consume\_policy\_json](#output\_pending\_auth\_consume\_policy\_json) | dynamodb:DeleteItem on the pending auth table. Attach to the role that completes a login by consuming the pending session on MFA confirmation. Null if create\_pending\_auth\_table = false. |
| <a name="output_pending_auth_create_policy_json"></a> [pending\_auth\_create\_policy\_json](#output\_pending\_auth\_create\_policy\_json) | dynamodb:PutItem on the pending auth table. Attach to the role that creates a pending session after the primary factor succeeds. Null if create\_pending\_auth\_table = false. |
| <a name="output_pending_auth_table_arn"></a> [pending\_auth\_table\_arn](#output\_pending\_auth\_table\_arn) | Pending auth table ARN (null if create\_pending\_auth\_table = false). |
| <a name="output_pending_auth_table_name"></a> [pending\_auth\_table\_name](#output\_pending\_auth\_table\_name) | Pending auth table name (null if create\_pending\_auth\_table = false). |
| <a name="output_recovery_codes_consume_policy_json"></a> [recovery\_codes\_consume\_policy\_json](#output\_recovery\_codes\_consume\_policy\_json) | dynamodb:DeleteItem on the recovery codes table. Attach to the role that redeems one recovery code. Null if create\_recovery\_codes\_table = false. |
| <a name="output_recovery_codes_regenerate_policy_json"></a> [recovery\_codes\_regenerate\_policy\_json](#output\_recovery\_codes\_regenerate\_policy\_json) | dynamodb:Query/BatchWriteItem on the recovery codes table. Attach to the role that regenerates a user's recovery code set. Null if create\_recovery\_codes\_table = false. |
| <a name="output_recovery_codes_table_arn"></a> [recovery\_codes\_table\_arn](#output\_recovery\_codes\_table\_arn) | Recovery codes table ARN (null if create\_recovery\_codes\_table = false). |
| <a name="output_recovery_codes_table_name"></a> [recovery\_codes\_table\_name](#output\_recovery\_codes\_table\_name) | Recovery codes table name (null if create\_recovery\_codes\_table = false). |
| <a name="output_verification_tokens_consume_policy_json"></a> [verification\_tokens\_consume\_policy\_json](#output\_verification\_tokens\_consume\_policy\_json) | dynamodb:DeleteItem on the verification tokens table. Attach to the role that consumes a single-use token. Null if create\_verification\_tokens\_table = false. |
| <a name="output_verification_tokens_issue_policy_json"></a> [verification\_tokens\_issue\_policy\_json](#output\_verification\_tokens\_issue\_policy\_json) | dynamodb:PutItem on the verification tokens table. Attach to the role that issues a single-use token. Null if create\_verification\_tokens\_table = false. |
| <a name="output_verification_tokens_table_arn"></a> [verification\_tokens\_table\_arn](#output\_verification\_tokens\_table\_arn) | Verification tokens table ARN (null if create\_verification\_tokens\_table = false). |
| <a name="output_verification_tokens_table_name"></a> [verification\_tokens\_table\_name](#output\_verification\_tokens\_table\_name) | Verification tokens table name (null if create\_verification\_tokens\_table = false). |
<!-- END_TF_DOCS -->
