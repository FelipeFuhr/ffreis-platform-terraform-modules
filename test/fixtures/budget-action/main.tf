terraform {
  required_version = ">= 1.5.0, < 2.0.0"

  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = ">= 5.0"
    }
  }
}

# No credentials and no network. Both module instances below avoid
# aws_caller_identity — the notify-only one because every action data source is
# counted off, the enforcing one because it supplies execution_role_arn — so a
# create-only plan resolves offline and this is a free test rather than a
# Terratest apply. aws_region and aws_partition read provider config, not STS.
provider "aws" {
  region                      = "us-east-1"
  access_key                  = "mock"
  secret_key                  = "mock"
  skip_credentials_validation = true
  skip_requesting_account_id  = true
  skip_metadata_api_check     = true
}

# The default every existing caller gets. Must stay notify-only, and must stay
# plannable without STS: adding an ungated aws_caller_identity to the module
# would break exactly this shape.
#trivy:ignore:*
module "notify_only" {
  source = "../../../modules/budget"

  name         = "fixture-notify-only"
  limit_amount = 100

  alert_email_addresses = ["budgets@example.com"]

  tags = {
    ManagedBy = "terratest"
  }
}

# The enforcing shape: an explicit-deny policy attached to the role that spends
# when actual spend hits 100% of the limit.
#trivy:ignore:*
module "enforcing" {
  source = "../../../modules/budget"

  name         = "fixture-enforcing"
  limit_amount = 150

  alert_email_addresses = ["budgets@example.com"]

  action = {
    iam = {
      policy_arn = "arn:aws:iam::123456789012:policy/fixture-deny-bedrock"
      roles      = ["fixture-icon-gen-worker-prod"]
    }
    subscriber_email_addresses = ["budgets@example.com"]
    execution_role_arn         = "arn:aws:iam::123456789012:role/fixture-budget-action"
  }

  tags = {
    ManagedBy = "terratest"
  }
}

output "notify_only_action_id" {
  value = module.notify_only.action_id
}

output "notify_only_enforces" {
  value = module.notify_only.action_enforces
}

output "enforcing_enforces" {
  value = module.enforcing.action_enforces
}
