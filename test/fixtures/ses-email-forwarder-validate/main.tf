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

#trivy:ignore:*
#checkov:skip=CKV_AWS_144:This validate-only fixture verifies module inputs and does not provision the caller-managed replication destination required for cross-region replication.
#checkov:skip=CKV2_AWS_62:SES inbound storage does not require native S3 event notifications because the receipt rule invokes Lambda directly.
module "forwarder" {
  source = "../../../modules/ses-email-forwarder"

  domain_name                = "example.com"
  hosted_zone_id             = "Z1234567890EXAMPLE"
  email_bucket_name          = "validate-example-email-bucket"
  s3_access_logs_bucket_name = "validate-example-access-logs"
  forwarding_aliases = {
    "*" = "inbox@example.net"
  }
  from_email = "forwarder@example.com"

  tags = {
    ManagedBy = "terratest"
  }
}

output "lambda_arn" {
  value = module.forwarder.lambda_arn
}