variable "bucket_name" {
  description = "S3 bucket name for the website content. Must be globally unique."
  type        = string
}

variable "api_gateway_url" {
  description = "API Gateway HTTP invoke URL (e.g. https://abc.execute-api.us-east-1.amazonaws.com). Required when api_path_patterns is non-empty."
  type        = string
  default     = null
}

variable "api_path_patterns" {
  description = "CloudFront path patterns to route to the API Gateway origin instead of S3. e.g. [\"/contact\", \"/flemming-inscricao\"]."
  type        = list(string)
  default     = []
}

variable "domain_names" {
  description = "Custom domain names (aliases) for the CloudFront distribution. Leave empty to use the CloudFront default domain."
  type        = list(string)
  default     = []
}

variable "acm_certificate_arn" {
  description = "ACM certificate ARN for the custom domain names. Must be in us-east-1. Required when domain_names is non-empty."
  type        = string
  default     = null
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
