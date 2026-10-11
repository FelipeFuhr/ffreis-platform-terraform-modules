<!-- BEGIN_TF_DOCS -->
## Requirements

| Name | Version |
|------|---------|
| <a name="requirement_terraform"></a> [terraform](#requirement\_terraform) | >= 1.5.0, < 2.0.0 |
| <a name="requirement_archive"></a> [archive](#requirement\_archive) | >= 2.4 |
| <a name="requirement_aws"></a> [aws](#requirement\_aws) | >= 5.0 |

## Providers

| Name | Version |
|------|---------|
| <a name="provider_archive"></a> [archive](#provider\_archive) | >= 2.4 |
| <a name="provider_aws"></a> [aws](#provider\_aws) | >= 5.0 |

## Modules

No modules.

## Resources

| Name | Type |
|------|------|
| [aws_cloudwatch_log_group.forwarder](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/cloudwatch_log_group) | resource |
| [aws_iam_role.forwarder](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/iam_role) | resource |
| [aws_iam_role_policy.forwarder](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/iam_role_policy) | resource |
| [aws_lambda_function.forwarder](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/lambda_function) | resource |
| [aws_lambda_permission.ses](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/lambda_permission) | resource |
| [aws_route53_record.mx](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/route53_record) | resource |
| [aws_s3_bucket.emails](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/s3_bucket) | resource |
| [aws_s3_bucket_lifecycle_configuration.emails](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/s3_bucket_lifecycle_configuration) | resource |
| [aws_s3_bucket_logging.emails](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/s3_bucket_logging) | resource |
| [aws_s3_bucket_policy.emails](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/s3_bucket_policy) | resource |
| [aws_s3_bucket_public_access_block.emails](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/s3_bucket_public_access_block) | resource |
| [aws_s3_bucket_server_side_encryption_configuration.emails](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/s3_bucket_server_side_encryption_configuration) | resource |
| [aws_ses_active_receipt_rule_set.this](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/ses_active_receipt_rule_set) | resource |
| [aws_ses_receipt_rule.forward](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/ses_receipt_rule) | resource |
| [aws_ses_receipt_rule_set.this](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/ses_receipt_rule_set) | resource |
| [archive_file.forwarder](https://registry.terraform.io/providers/hashicorp/archive/latest/docs/data-sources/file) | data source |
| [aws_caller_identity.current](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/data-sources/caller_identity) | data source |
| [aws_iam_policy_document.emails_bucket_policy](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/data-sources/iam_policy_document) | data source |
| [aws_iam_policy_document.lambda_assume](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/data-sources/iam_policy_document) | data source |
| [aws_iam_policy_document.lambda_policy](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/data-sources/iam_policy_document) | data source |
| [aws_partition.current](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/data-sources/partition) | data source |
| [aws_region.current](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/data-sources/region) | data source |

## Inputs

| Name | Description | Type | Default | Required |
|------|-------------|------|---------|:--------:|
| <a name="input_activate_rule_set"></a> [activate\_rule\_set](#input\_activate\_rule\_set) | Whether to set this receipt rule set as the active one in the account. Activating a rule set is account-wide and will replace any currently active rule set in the region. | `bool` | `true` | no |
| <a name="input_domain_name"></a> [domain\_name](#input\_domain\_name) | Domain to receive email for (e.g. example.com). Must already have an active SES domain identity. | `string` | n/a | yes |
| <a name="input_email_bucket_kms_key_arn"></a> [email\_bucket\_kms\_key\_arn](#input\_email\_bucket\_kms\_key\_arn) | Optional customer-managed KMS key ARN for inbound email bucket encryption. Null uses the AWS-managed S3 KMS key with no fixed monthly CMK cost. | `string` | `null` | no |
| <a name="input_email_bucket_name"></a> [email\_bucket\_name](#input\_email\_bucket\_name) | S3 bucket name for storing raw inbound emails. Must be globally unique. | `string` | n/a | yes |
| <a name="input_email_key_prefix"></a> [email\_key\_prefix](#input\_email\_key\_prefix) | S3 key prefix (no trailing slash) where SES stores raw emails. | `string` | `"emails"` | no |
| <a name="input_forwarding_aliases"></a> [forwarding\_aliases](#input\_forwarding\_aliases) | Map of lower-case local-part → destination email address. Use "*" as a catch-all key. Example: { infrastructure = "me@gmail.com", felipefuhrdosreis = "me@gmail.com" } | `map(string)` | n/a | yes |
| <a name="input_from_email"></a> [from\_email](#input\_from\_email) | SES-verified sender address used when re-sending forwarded mail (e.g. forwarding@example.com). Must be within the verified domain. | `string` | n/a | yes |
| <a name="input_hosted_zone_id"></a> [hosted\_zone\_id](#input\_hosted\_zone\_id) | Route 53 hosted zone ID for the domain. Used to create the MX record pointing to SES inbound. | `string` | n/a | yes |
| <a name="input_log_kms_key_arn"></a> [log\_kms\_key\_arn](#input\_log\_kms\_key\_arn) | Optional customer-managed KMS key ARN for the email forwarder CloudWatch log group. Null uses the default CloudWatch Logs encryption with no fixed monthly CMK cost. | `string` | `null` | no |
| <a name="input_log_retention_days"></a> [log\_retention\_days](#input\_log\_retention\_days) | CloudWatch log retention for the forwarder Lambda. | `number` | `365` | no |
| <a name="input_rule_set_name"></a> [rule\_set\_name](#input\_rule\_set\_name) | SES receipt rule set name. This rule set will be set as the active one in the account when activate\_rule\_set is true. | `string` | `"default-rule-set"` | no |
| <a name="input_s3_access_logs_bucket_name"></a> [s3\_access\_logs\_bucket\_name](#input\_s3\_access\_logs\_bucket\_name) | Central S3 bucket name that receives access logs for the inbound email bucket. | `string` | n/a | yes |
| <a name="input_s3_access_logs_prefix"></a> [s3\_access\_logs\_prefix](#input\_s3\_access\_logs\_prefix) | Prefix for inbound email bucket access logs in the central logging bucket. Empty uses a module default. | `string` | `""` | no |
| <a name="input_tags"></a> [tags](#input\_tags) | Tags applied to all resources. | `map(string)` | `{}` | no |

## Outputs

| Name | Description |
|------|-------------|
| <a name="output_email_bucket_arn"></a> [email\_bucket\_arn](#output\_email\_bucket\_arn) | S3 bucket ARN where raw inbound emails are stored. |
| <a name="output_email_bucket_id"></a> [email\_bucket\_id](#output\_email\_bucket\_id) | S3 bucket name where raw inbound emails are stored. |
| <a name="output_lambda_arn"></a> [lambda\_arn](#output\_lambda\_arn) | ARN of the email forwarder Lambda function. |
| <a name="output_lambda_function_name"></a> [lambda\_function\_name](#output\_lambda\_function\_name) | Name of the email forwarder Lambda function. |
| <a name="output_rule_set_name"></a> [rule\_set\_name](#output\_rule\_set\_name) | SES receipt rule set name (set as the active rule set). |
<!-- END_TF_DOCS -->