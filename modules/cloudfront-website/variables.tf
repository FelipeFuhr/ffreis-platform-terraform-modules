variable "bucket_name" {
  description = "S3 bucket name for the website content. Must be globally unique."
  type        = string
}

variable "kms_key_arn" {
  description = "Optional customer-managed KMS key ARN for website bucket encryption. Null uses the AWS-managed S3 KMS key with no fixed monthly CMK cost."
  type        = string
  default     = null
}

variable "s3_access_logs_bucket_name" {
  description = "Central S3 bucket name that receives access logs for the website bucket."
  type        = string

  validation {
    condition     = trimspace(var.s3_access_logs_bucket_name) != ""
    error_message = "s3_access_logs_bucket_name must be a non-empty bucket name."
  }
}

variable "s3_access_logs_prefix" {
  description = "Prefix for website bucket access logs in the central logging bucket. Empty uses a module default."
  type        = string
  default     = ""
}

variable "cloudfront_access_logs_bucket_domain_name" {
  description = "S3 bucket domain name that receives CloudFront standard logs, for example logs-bucket.s3.amazonaws.com."
  type        = string

  validation {
    condition     = trimspace(var.cloudfront_access_logs_bucket_domain_name) != ""
    error_message = "cloudfront_access_logs_bucket_domain_name must be a non-empty S3 bucket domain name."
  }
}

variable "cloudfront_access_logs_prefix" {
  description = "Prefix for CloudFront access logs in the logging bucket. Empty uses a module default."
  type        = string
  default     = ""
}

variable "waf_web_acl_id" {
  description = "Optional WAF Web ACL ID or ARN associated with the CloudFront distribution. Null disables WAF association."
  type        = string
  default     = null

  validation {
    condition     = var.waf_web_acl_id == null || try(trimspace(var.waf_web_acl_id), "") != ""
    error_message = "waf_web_acl_id must be null or a non-empty Web ACL identifier."
  }
}

variable "api_gateway_url" {
  description = "API Gateway HTTP invoke URL (e.g. https://abc.execute-api.us-east-1.amazonaws.com). Required when api_path_patterns is non-empty."
  type        = string
  default     = null

  validation {
    condition     = length(var.api_path_patterns) == 0 || var.api_gateway_url != null
    error_message = "api_gateway_url must be provided when api_path_patterns is non-empty."
  }
}

variable "api_path_patterns" {
  description = "CloudFront path patterns to route to the API Gateway origin instead of S3. e.g. [\"/contact\", \"/flemming-inscricao\"]."
  type        = list(string)
  default     = []
}

variable "domain_names" {
  description = "Custom domain names (aliases) for the CloudFront distribution. Leave empty to use the CloudFront default domain, which AWS restricts to the legacy TLSv1 viewer policy."
  type        = list(string)
  default     = []
}

variable "acm_certificate_arn" {
  description = "ACM certificate ARN for the custom domain names. Must be in us-east-1. Required when domain_names is non-empty."
  type        = string
  default     = null

  validation {
    condition     = length(var.domain_names) == 0 || try(trimspace(var.acm_certificate_arn), "") != ""
    error_message = "acm_certificate_arn must be provided and non-empty when domain_names is non-empty."
  }
}

variable "price_class" {
  description = "CloudFront price class. PriceClass_100 = NA+EU only (cheapest). PriceClass_200 = +Asia/ME/Africa. PriceClass_All = all edge locations."
  type        = string
  default     = "PriceClass_100"

  validation {
    condition     = contains(["PriceClass_100", "PriceClass_200", "PriceClass_All"], var.price_class)
    error_message = "Must be PriceClass_100, PriceClass_200, or PriceClass_All."
  }
}

variable "default_root_object" {
  description = "Object to return when the root URL is requested."
  type        = string
  default     = "index.html"
}

variable "not_found_page" {
  description = "Path to the 404 error page (must exist in the S3 bucket)."
  type        = string
  default     = "/404.html"
}

variable "error_page" {
  description = "Path to the 500 error page (must exist in the S3 bucket)."
  type        = string
  default     = "/500.html"
}

variable "tags" {
  description = "Tags applied to all resources."
  type        = map(string)
  default     = {}
}
