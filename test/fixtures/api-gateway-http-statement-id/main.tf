terraform {
  required_version = ">= 1.5.0, < 2.0.0"

  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = ">= 5.0"
    }
  }
}

# No credentials and no network. The module declares no data sources, so a
# create-only plan resolves every statement_id from known values offline; the
# skip_* flags keep the provider from reaching STS just to initialise. That is
# what makes this a free test rather than a Terratest apply.
provider "aws" {
  region                      = "us-east-1"
  access_key                  = "mock"
  secret_key                  = "mock"
  skip_credentials_validation = true
  skip_requesting_account_id  = true
  skip_metadata_api_check     = true
}

locals {
  lambda_arn = "arn:aws:apigateway:us-east-1:lambda:path/2015-03-31/functions/arn:aws:lambda:us-east-1:123456789012:function:fixture/invocations"
}

#trivy:ignore:*
module "api" {
  source = "../../../modules/api-gateway-http"

  name = "statement-id-fixture"

  # Every key below is a legal API Gateway route key. The whole point of the
  # fixture is that "legal route key" is a far wider set than the four
  # characters the statement_id sanitizer used to handle.
  routes = {
    # The one that broke a live apply: a file-extension route. The "." reached
    # statement_id untouched, and AWS rejects statement_id at CREATE time, so
    # it passed review AND `terraform plan` and failed partway into the apply.
    "GET /api/sessions/{id}/playlist.m3u8" = { integration_uri = local.lambda_arn, authorizer = "none" }

    # Ordinary shapes, here to pin the NO-CHURN property: these must keep
    # producing byte-identical statement_ids. statement_id forces replacement,
    # so a "tidier" single-regex rewrite would destroy and recreate every
    # lambda permission in the fleet to fix a bug in none of them.
    "GET /api/sessions/{id}/playlist" = { integration_uri = local.lambda_arn, authorizer = "none" }
    "POST /api/issue"                 = { integration_uri = local.lambda_arn, authorizer = "none" }
    "GET /api/detect/{job_id}"        = { integration_uri = local.lambda_arn, authorizer = "none" }

    # Other legal-but-unusual keys, so the next one does not reopen this.
    "ANY /api/v1.2/thing"         = { integration_uri = local.lambda_arn, authorizer = "none" }
    "GET /api/report.json"        = { integration_uri = local.lambda_arn, authorizer = "none" }
    "GET /api/files/{proxy+}"     = { integration_uri = local.lambda_arn, authorizer = "none" }
    "GET /api/a~b/c:d/{e}.tar.gz" = { integration_uri = local.lambda_arn, authorizer = "none" }
  }

  tags = {
    ManagedBy = "terratest"
  }
}
