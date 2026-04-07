terraform {
  required_version = ">= 1.5.0, < 2.0.0"

  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = ">= 5.0"
    }
  }
}

provider "aws" {
  region = "us-east-1"
}

module "website" {
  source = "../../../modules/cloudfront-website"

  bucket_name                               = "validate-example-static-site-bucket"
  s3_access_logs_bucket_name                = "validate-example-access-logs"
  cloudfront_access_logs_bucket_domain_name = "validate-example-access-logs.s3.amazonaws.com"
  waf_web_acl_id                            = "arn:aws:wafv2:us-east-1:123456789012:global/webacl/example/11111111-1111-1111-1111-111111111111"
  api_gateway_url                           = "https://abc123.execute-api.us-east-1.amazonaws.com"
  api_path_patterns                         = ["/api/*"]

  tags = {
    ManagedBy = "terratest"
  }
}

output "distribution_arn" {
  value = module.website.distribution_arn
}