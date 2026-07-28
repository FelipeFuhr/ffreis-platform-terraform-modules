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
| [aws_cloudfront_distribution.website](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/cloudfront_distribution) | resource |
| [aws_cloudfront_origin_access_control.website](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/cloudfront_origin_access_control) | resource |
| [aws_s3_bucket.website](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/s3_bucket) | resource |
| [aws_s3_bucket_lifecycle_configuration.website](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/s3_bucket_lifecycle_configuration) | resource |
| [aws_s3_bucket_logging.website](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/s3_bucket_logging) | resource |
| [aws_s3_bucket_policy.website](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/s3_bucket_policy) | resource |
| [aws_s3_bucket_public_access_block.website](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/s3_bucket_public_access_block) | resource |
| [aws_s3_bucket_server_side_encryption_configuration.website](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/s3_bucket_server_side_encryption_configuration) | resource |
| [aws_s3_bucket_versioning.website](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/s3_bucket_versioning) | resource |
| [terraform_data.destroy_guard](https://registry.terraform.io/providers/hashicorp/terraform/latest/docs/resources/data) | resource |
| [aws_cloudfront_response_headers_policy.security_headers](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/data-sources/cloudfront_response_headers_policy) | data source |
| [aws_iam_policy_document.website_bucket](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/data-sources/iam_policy_document) | data source |

## Inputs

| Name | Description | Type | Default | Required |
|------|-------------|------|---------|:--------:|
| <a name="input_acm_certificate_arn"></a> [acm\_certificate\_arn](#input\_acm\_certificate\_arn) | ACM certificate ARN for the custom domain names. Must be in us-east-1. Required when domain\_names is non-empty. | `string` | `null` | no |
| <a name="input_api_gateway_url"></a> [api\_gateway\_url](#input\_api\_gateway\_url) | API Gateway HTTP invoke URL (e.g. https://abc.execute-api.us-east-1.amazonaws.com). Required when api\_path\_patterns is non-empty. | `string` | `null` | no |
| <a name="input_api_origin_custom_headers"></a> [api\_origin\_custom\_headers](#input\_api\_origin\_custom\_headers) | Headers CloudFront injects on every request forwarded to the API origin, as a<br/>name => value map.<br/><br/>A Lambda Function URL with authorization\_type = "NONE" is publicly invokable, so<br/>CloudFront alone is not an access control — anything that can reach the Function URL<br/>bypasses the distribution entirely. Injecting a shared secret here lets the origin<br/>verify a request actually came through CloudFront and reject the rest.<br/><br/>Defaults to empty, which emits no custom\_header block at all, so existing consumers<br/>are unaffected. | `map(string)` | `{}` | no |
| <a name="input_api_path_patterns"></a> [api\_path\_patterns](#input\_api\_path\_patterns) | CloudFront path patterns to route to the API Gateway origin instead of S3. e.g. ["/contact", "/flemming-inscricao"]. | `list(string)` | `[]` | no |
| <a name="input_bucket_name"></a> [bucket\_name](#input\_bucket\_name) | S3 bucket name for the website content. Must be globally unique. | `string` | n/a | yes |
| <a name="input_cache_policy_id"></a> [cache\_policy\_id](#input\_cache\_policy\_id) | CloudFront managed cache policy ID for the default cache behaviour. Use CachingOptimized (658327ea) in prod and CachingDisabled (4135ea2d) in dev to avoid invalidation costs and ensure fresh responses during development. | `string` | `"658327ea-f89d-4fab-a63d-7e88639e58f6"` | no |
| <a name="input_cloudfront_access_logs_bucket_domain_name"></a> [cloudfront\_access\_logs\_bucket\_domain\_name](#input\_cloudfront\_access\_logs\_bucket\_domain\_name) | S3 bucket domain name that receives CloudFront standard logs, for example logs-bucket.s3.amazonaws.com. | `string` | n/a | yes |
| <a name="input_cloudfront_access_logs_prefix"></a> [cloudfront\_access\_logs\_prefix](#input\_cloudfront\_access\_logs\_prefix) | Prefix for CloudFront access logs in the logging bucket. Empty uses a module default. | `string` | `""` | no |
| <a name="input_cloudfront_function_arn"></a> [cloudfront\_function\_arn](#input\_cloudfront\_function\_arn) | ARN of a CloudFront Function to attach to the default cache behaviour as a viewer-response event. Set to null to skip. | `string` | `null` | no |
| <a name="input_default_root_object"></a> [default\_root\_object](#input\_default\_root\_object) | Object to return when the root URL is requested. | `string` | `"index.html"` | no |
| <a name="input_domain_names"></a> [domain\_names](#input\_domain\_names) | Custom domain names (aliases) for the CloudFront distribution. Leave empty to use the CloudFront default domain, which AWS restricts to the legacy TLSv1 viewer policy. | `list(string)` | `[]` | no |
| <a name="input_error_caching_min_ttl"></a> [error\_caching\_min\_ttl](#input\_error\_caching\_min\_ttl) | Minimum TTL in seconds for caching error responses. Set to 0 during debugging to see errors immediately. Higher values (e.g., 300) reduce origin load in production. | `number` | `10` | no |
| <a name="input_error_page"></a> [error\_page](#input\_error\_page) | Path to the 500 error page (must exist in the S3 bucket). | `string` | `"/500.html"` | no |
| <a name="input_kms_key_arn"></a> [kms\_key\_arn](#input\_kms\_key\_arn) | Optional customer-managed KMS key ARN for website bucket encryption. Null uses the AWS-managed S3 KMS key with no fixed monthly CMK cost. | `string` | `null` | no |
| <a name="input_not_found_page"></a> [not\_found\_page](#input\_not\_found\_page) | Path to the 404 error page (must exist in the S3 bucket). | `string` | `"/404.html"` | no |
| <a name="input_prevent_destroy"></a> [prevent\_destroy](#input\_prevent\_destroy) | Set true in production to block accidental resource destruction. Uses a terraform\_data guard — to destroy the module, set this to false and apply first. | `bool` | `false` | no |
| <a name="input_price_class"></a> [price\_class](#input\_price\_class) | CloudFront price class. PriceClass\_100 = NA+EU only (cheapest). PriceClass\_200 = +Asia/ME/Africa. PriceClass\_All = all edge locations. | `string` | `"PriceClass_100"` | no |
| <a name="input_s3_access_logs_bucket_name"></a> [s3\_access\_logs\_bucket\_name](#input\_s3\_access\_logs\_bucket\_name) | Central S3 bucket name that receives access logs for the website bucket. | `string` | n/a | yes |
| <a name="input_s3_access_logs_prefix"></a> [s3\_access\_logs\_prefix](#input\_s3\_access\_logs\_prefix) | Prefix for website bucket access logs in the central logging bucket. Empty uses a module default. | `string` | `""` | no |
| <a name="input_tags"></a> [tags](#input\_tags) | Tags applied to all resources. | `map(string)` | `{}` | no |
| <a name="input_viewer_request_function_arn"></a> [viewer\_request\_function\_arn](#input\_viewer\_request\_function\_arn) | ARN of a CloudFront Function to attach to the default cache behaviour as a viewer-request event (runs before the request reaches the origin). Use for URL rewriting. Set to null to skip. | `string` | `null` | no |
| <a name="input_waf_web_acl_id"></a> [waf\_web\_acl\_id](#input\_waf\_web\_acl\_id) | Optional WAF Web ACL ID or ARN associated with the CloudFront distribution. Null disables WAF association. | `string` | `null` | no |

## Outputs

| Name | Description |
|------|-------------|
| <a name="output_bucket_arn"></a> [bucket\_arn](#output\_bucket\_arn) | S3 bucket ARN. |
| <a name="output_bucket_id"></a> [bucket\_id](#output\_bucket\_id) | S3 bucket name (ID). |
| <a name="output_bucket_regional_domain_name"></a> [bucket\_regional\_domain\_name](#output\_bucket\_regional\_domain\_name) | S3 bucket regional domain name. |
| <a name="output_cloudfront_url"></a> [cloudfront\_url](#output\_cloudfront\_url) | Direct HTTPS URL to the CloudFront distribution. Use this to verify the distribution works before DNS propagation. |
| <a name="output_distribution_arn"></a> [distribution\_arn](#output\_distribution\_arn) | CloudFront distribution ARN. |
| <a name="output_distribution_domain_name"></a> [distribution\_domain\_name](#output\_distribution\_domain\_name) | CloudFront distribution domain name (*.cloudfront.net). Use as the alias target for Route 53 records. |
| <a name="output_distribution_hosted_zone_id"></a> [distribution\_hosted\_zone\_id](#output\_distribution\_hosted\_zone\_id) | Route 53 hosted zone ID for the CloudFront distribution. Use with alias records. |
| <a name="output_distribution_id"></a> [distribution\_id](#output\_distribution\_id) | CloudFront distribution ID. |
| <a name="output_encryption_algorithm"></a> [encryption\_algorithm](#output\_encryption\_algorithm) | S3 bucket encryption algorithm in use (AES256 = SSE-S3, aws:kms = SSE-KMS). |
<!-- END_TF_DOCS -->