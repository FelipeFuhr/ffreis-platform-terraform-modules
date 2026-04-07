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

#checkov:skip=CKV_AWS_310:This validate-only fixture exercises a module that manages a single website origin plus an optional API origin; redundant origin failover must be caller-designed.
#checkov:skip=CKV2_AWS_47:This fixture supplies a caller-managed WAF Web ACL identifier; AMR enforcement belongs to that external WAF policy, not the module wiring test.
#checkov:skip=CKV_AWS_144:This validate-only fixture does not provision a caller-managed replication destination bucket; CRR is intentionally outside fixture scope.
#checkov:skip=CKV2_AWS_62:Static website origin buckets in this module do not emit native S3 event notifications by default; integrations are caller-specific.
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