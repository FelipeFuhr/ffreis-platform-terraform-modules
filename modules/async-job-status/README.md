# async-job-status

The honest-success correlation store for the async request-reply (job-status) UX
pattern. Backs "show the user success only once the work is *processed*".

```
browser ─POST─► submit Lambda ─publish DomainEvent─► (push|ESM) consumer ─work─► PutItem terminal status
   │              └─202 {job_id}=correlation_id                                    to THIS table (TTL ~1h)
   └─GET /api/status/{job_id}─► status Lambda (SYNC) ─GetItem─► pending|succeeded|failed
```

This module owns only the **jobs DynamoDB table** (keyed by `job_id` ==
`DomainEvent.correlation_id`) and the **IAM policy-JSON outputs**. The caller
attaches `status_writer_policy_json` to the async **consumer** role (its last
step writes the terminal status — a conditional `PutItem` that doubles as the
idempotency record) and `status_reader_policy_json` to a caller-owned **sync
status Lambda** wired to `GET /api/status/{job_id}`.

`$0` fixed cost: `PAY_PER_REQUEST`, AWS-owned encryption (no KMS), TTL'd rows.

## Usage

```hcl
module "jobs" {
  source = "git::https://github.com/FelipeFuhr/ffreis-platform-terraform-modules.git//modules/async-job-status?ref=v2.2.0"

  name = "my-product-jobs-${var.environment}"
  tags = merge(module.tags.tags, { CostCenter = "my-product" })
}

# consumer role: attach module.jobs.status_writer_policy_json
# status Lambda role: attach module.jobs.status_reader_policy_json
```
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

## Modules

| Name | Source | Version |
|------|--------|---------|
| <a name="module_table"></a> [table](#module\_table) | ../dynamodb-table | n/a |

## Resources

| Name | Type |
|------|------|
| [aws_iam_policy_document.status_reader](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/data-sources/iam_policy_document) | data source |
| [aws_iam_policy_document.status_writer](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/data-sources/iam_policy_document) | data source |

## Inputs

| Name | Description | Type | Default | Required |
|------|-------------|------|---------|:--------:|
| <a name="input_deletion_protection_enabled"></a> [deletion\_protection\_enabled](#input\_deletion\_protection\_enabled) | DynamoDB deletion protection. Job status is transient (TTL'd), so false by default. | `bool` | `false` | no |
| <a name="input_name"></a> [name](#input\_name) | Jobs table name, e.g. '<site>-jobs-<env>'. | `string` | n/a | yes |
| <a name="input_tags"></a> [tags](#input\_tags) | Tags applied to the table (use the tagging module output; set a per-product CostCenter). | `map(string)` | `{}` | no |
| <a name="input_ttl_attribute"></a> [ttl\_attribute](#input\_ttl\_attribute) | DynamoDB TTL attribute (unix epoch seconds). Rows self-expire after the job result is no longer needed (~1h). The consumer sets it on the terminal-status write. | `string` | `"expires_at"` | no |

## Outputs

| Name | Description |
|------|-------------|
| <a name="output_status_reader_policy_json"></a> [status\_reader\_policy\_json](#output\_status\_reader\_policy\_json) | dynamodb:GetItem on the jobs table. Attach to the sync status Lambda role (GET /api/status/{job\_id}). |
| <a name="output_status_writer_policy_json"></a> [status\_writer\_policy\_json](#output\_status\_writer\_policy\_json) | dynamodb:PutItem/UpdateItem/GetItem on the jobs table. Attach to the async consumer role (it writes the terminal status). |
| <a name="output_table_arn"></a> [table\_arn](#output\_table\_arn) | Jobs table ARN. |
| <a name="output_table_name"></a> [table\_name](#output\_table\_name) | Jobs table name — set as JOBS\_TABLE on the consumer and the status Lambda. |
<!-- END_TF_DOCS -->
