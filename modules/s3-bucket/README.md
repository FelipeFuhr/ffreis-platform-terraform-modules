<!-- BEGIN_TF_DOCS -->
## Requirements

| Name | Version |
|------|---------|
| <a name="requirement_terraform"></a> [terraform](#requirement\_terraform) | >= 1.5.0, < 2.0.0 |
| <a name="requirement_aws"></a> [aws](#requirement\_aws) | >= 5.0 |

## Providers

| Name | Version |
|------|---------|
| <a name="provider_aws"></a> [aws](#provider\_aws) | 6.72.0 |
| <a name="provider_terraform"></a> [terraform](#provider\_terraform) | n/a |

## Modules

No modules.

## Resources

| Name | Type |
|------|------|
| [aws_s3_bucket.this](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/s3_bucket) | resource |
| [aws_s3_bucket_intelligent_tiering_configuration.this](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/s3_bucket_intelligent_tiering_configuration) | resource |
| [aws_s3_bucket_lifecycle_configuration.this](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/s3_bucket_lifecycle_configuration) | resource |
| [aws_s3_bucket_logging.this](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/s3_bucket_logging) | resource |
| [aws_s3_bucket_object_lock_configuration.this](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/s3_bucket_object_lock_configuration) | resource |
| [aws_s3_bucket_policy.tls_enforce](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/s3_bucket_policy) | resource |
| [aws_s3_bucket_public_access_block.this](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/s3_bucket_public_access_block) | resource |
| [aws_s3_bucket_server_side_encryption_configuration.this](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/s3_bucket_server_side_encryption_configuration) | resource |
| [aws_s3_bucket_versioning.this](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/s3_bucket_versioning) | resource |
| [terraform_data.destroy_guard](https://registry.terraform.io/providers/hashicorp/terraform/latest/docs/resources/data) | resource |
| [aws_iam_policy_document.tls_enforce](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/data-sources/iam_policy_document) | data source |

## Inputs

| Name | Description | Type | Default | Required |
|------|-------------|------|---------|:--------:|
| <a name="input_abort_incomplete_multipart_upload_days"></a> [abort\_incomplete\_multipart\_upload\_days](#input\_abort\_incomplete\_multipart\_upload\_days) | Days after initiation to abort incomplete multipart uploads. Set to 0 to disable. | `number` | `7` | no |
| <a name="input_bucket"></a> [bucket](#input\_bucket) | S3 bucket name. | `string` | n/a | yes |
| <a name="input_force_destroy"></a> [force\_destroy](#input\_force\_destroy) | Allow Terraform to destroy the bucket even when it contains objects. | `bool` | `false` | no |
| <a name="input_intelligent_tiering"></a> [intelligent\_tiering](#input\_intelligent\_tiering) | Enable S3 Intelligent-Tiering to automatically move objects to cheaper tiers. | `bool` | `false` | no |
| <a name="input_kms_master_key_id"></a> [kms\_master\_key\_id](#input\_kms\_master\_key\_id) | KMS key ARN/ID for aws:kms SSE. Required when sse\_algorithm = 'aws:kms'. | `string` | `null` | no |
| <a name="input_lifecycle_rules"></a> [lifecycle\_rules](#input\_lifecycle\_rules) | Optional lifecycle rules. Example:<br/>  [{<br/>    id      = "expire-old-versions"<br/>    enabled = true<br/>    noncurrent\_version\_expiration\_days = 90<br/>  }] | <pre>list(object({<br/>    id      = string<br/>    enabled = bool<br/>    # Expiration of current objects (days). null = skip.<br/>    expiration_days = optional(number, null)<br/>    # Expiration of noncurrent versions (days). null = skip.<br/>    noncurrent_version_expiration_days = optional(number, null)<br/>  }))</pre> | `[]` | no |
| <a name="input_logging_target_bucket"></a> [logging\_target\_bucket](#input\_logging\_target\_bucket) | S3 bucket to receive access logs. Leave empty to skip access logging; pass an empty string for the logging bucket itself to break the circular dependency. | `string` | `""` | no |
| <a name="input_logging_target_prefix"></a> [logging\_target\_prefix](#input\_logging\_target\_prefix) | Log prefix when access logging is enabled. | `string` | `""` | no |
| <a name="input_manage_bucket_policy"></a> [manage\_bucket\_policy](#input\_manage\_bucket\_policy) | Whether this module owns the bucket policy. Default true: the module<br/>attaches a TLS-only policy denying any non-HTTPS request.<br/><br/>Set false ONLY when the caller must own the policy because the bucket needs<br/>additional statements — most commonly a CloudFront OAC read grant. A bucket<br/>has exactly ONE policy document, so a caller that attaches its own while<br/>this module also attaches one creates two resources contending for a single<br/>object: whichever applies last wins and the other's statements disappear,<br/>then come back on the next apply. The oscillation is silent, and it<br/>surfaces only as the CDN origin intermittently losing read access.<br/><br/>Opting out does NOT mean losing the control: the TLS statement is exposed<br/>as the `tls_enforce_policy_json` output. Merge it into the caller's<br/>document via `override_policy_documents` so HTTPS stays enforced. | `bool` | `true` | no |
| <a name="input_object_lock_days"></a> [object\_lock\_days](#input\_object\_lock\_days) | Default Object Lock retention in days. 0 uses years instead. | `number` | `0` | no |
| <a name="input_object_lock_enabled"></a> [object\_lock\_enabled](#input\_object\_lock\_enabled) | Enable S3 Object Lock (WORM). Cannot be disabled after creation. | `bool` | `false` | no |
| <a name="input_object_lock_mode"></a> [object\_lock\_mode](#input\_object\_lock\_mode) | Object Lock retention mode when object\_lock\_enabled = true: 'GOVERNANCE' or 'COMPLIANCE'. | `string` | `"GOVERNANCE"` | no |
| <a name="input_object_lock_years"></a> [object\_lock\_years](#input\_object\_lock\_years) | Default Object Lock retention in years. Used when object\_lock\_days = 0. | `number` | `1` | no |
| <a name="input_prevent_destroy"></a> [prevent\_destroy](#input\_prevent\_destroy) | Set true in production to block accidental resource destruction. Uses a terraform\_data guard — to destroy the module, set this to false and apply first. | `bool` | `false` | no |
| <a name="input_sse_algorithm"></a> [sse\_algorithm](#input\_sse\_algorithm) | Server-side encryption algorithm. 'AES256' or 'aws:kms'. | `string` | `"aws:kms"` | no |
| <a name="input_tags"></a> [tags](#input\_tags) | Tags applied to all resources. | `map(string)` | `{}` | no |
| <a name="input_versioning_enabled"></a> [versioning\_enabled](#input\_versioning\_enabled) | Enable S3 Versioning. Recommended true for state/artifact buckets. | `bool` | `true` | no |

## Outputs

| Name | Description |
|------|-------------|
| <a name="output_arn"></a> [arn](#output\_arn) | Bucket ARN. |
| <a name="output_bucket_domain_name"></a> [bucket\_domain\_name](#output\_bucket\_domain\_name) | Bucket domain name (bucket.s3.amazonaws.com). |
| <a name="output_bucket_regional_domain_name"></a> [bucket\_regional\_domain\_name](#output\_bucket\_regional\_domain\_name) | Region-specific domain name (bucket.s3.region.amazonaws.com). |
| <a name="output_hosted_zone_id"></a> [hosted\_zone\_id](#output\_hosted\_zone\_id) | Route 53 hosted zone ID for the bucket's region (useful for alias records). |
| <a name="output_id"></a> [id](#output\_id) | Bucket name / ID. |
| <a name="output_tls_enforce_policy_json"></a> [tls\_enforce\_policy\_json](#output\_tls\_enforce\_policy\_json) | The TLS-only (DenyHTTP) policy document as JSON, always computed whether or<br/>not this module attaches it.<br/><br/>For callers that set `manage_bucket_policy = false` and own the bucket<br/>policy themselves: feed this into their own<br/>`aws_iam_policy_document`'s `override_policy_documents` so the HTTPS<br/>requirement survives taking over policy ownership. |
<!-- END_TF_DOCS -->