# tagging

Single source of truth for AWS resource tags across the ffreis workspace.

Call this module once per Terraform root module, pass its `tags` output to
`provider "aws" { default_tags { … } }`, and forward `module.tags.tags` to
every nested module that takes a `tags` input.

## Usage

```hcl
module "tags" {
  source = "git::https://github.com/FelipeFuhr/ffreis-platform-terraform-modules.git//modules/tagging?ref=v2.0.0"

  project           = "flemming"
  environment       = var.environment              # dev | prod
  stack             = "flemming"
  layer             = "flemming-infra"
  terraform_repo    = "ffreis-flemming-infra"
  terraform_root    = "infra"
  terraform_version = "1.9.8"
  cost_center       = "flemming"                   # per-product, not "engineering"
  domain            = "flemming.com.br"
  lifecycle_state   = var.environment == "prod" ? "production" : "development"
  fixed_cost_tier   = "low"                        # honest fixed monthly cost band

  # Optional defaults below already set:
  # owner               = "felipefuhr"
  # managed_by          = "terraform"
  # compliance_framework = "none"
  # data_classification  = "internal"
  # backup_policy        = "none"
}

provider "aws" {
  default_tags { tags = module.tags.tags }
}
```

Per-resource override (rare — usually `default_tags` is enough):

```hcl
resource "aws_dynamodb_table" "experiments" {
  # …
  tags = merge(module.tags.tags, {
    LifecycleState = "experiment"
    FixedCostTier  = "none"
  })
}
```

## Tag schema

| Tag | Required? | Notes |
|---|---|---|
| `Project` | ✅ | Per-product slug (`flemming`, `petlook`, `ffreis-website`, …) |
| `Environment` | ✅ | `dev` or `prod` (validated) |
| `Stack` | ✅ | Logical grouping; usually = `Project` |
| `Layer` | ✅ | Sub-component within stack |
| `ManagedBy` | ✅ | Defaults to `terraform` |
| `TerraformRepo` | ✅ | Repo name |
| `TerraformRoot` | ✅ | Root module path (`infra` / `stack`) |
| `CostCenter` | ✅ | **Per-product**, drives Cost Explorer grouping |
| `Owner` | ✅ | Defaults to `felipefuhr` |
| `Compliance` | ✅ | Defaults to `none` |
| `DataClassification` | ✅ | Defaults to `internal`, validated |
| `BackupPolicy` | ✅ | Defaults to `none` |
| `LifecycleState` | ✅ | `production` \| `development` \| `experiment` \| `legacy` (validated) |
| `FixedCostTier` | ✅ | `none` \| `low` (<$1/mo) \| `medium` ($1-$10/mo) \| `high` (>$10/mo) (validated) |
| `Domain` | ✅ | `flemming.com.br` \| `ffreis.com` \| `petlook.ai` \| `petlook.app` \| `dashboard.ffreis.com` \| `uxstoryteller.ffreis.com` \| `pocketworldarcade.ffreis.com` \| `pocketworldarcade.app` \| `urbs.ffreis.com` \| `media.ffreis.com` \| `internal` (validated) |
| `TerraformVersion` | conditional | Emitted only if `terraform_version` is set |
| `Repository` | conditional | Emitted only if `repository` is set |

## Decision rules

### `LifecycleState`
- `production` — serves real users; deletion would cause an incident.
- `development` — dev / staging twin of a production resource; recreatable.
- `experiment` — short-lived spike, PoC, or one-off; safe to delete after the experiment ends.
- `legacy` — superseded by something newer; flagged for cleanup. Audit queries use this tag.

### `FixedCostTier`
Set honestly. Cost Explorer queries like *"show me all medium+ fixed-cost resources"* depend on it.
- `none` — pay-per-request only (Lambda, DDB on-demand, CloudFront, API Gateway, S3 storage).
- `low` — < $1/mo (Route 53 zone $0.50, single CloudWatch alarm $0.10, etc.).
- `medium` — $1 to $10/mo (KMS key $1, WAF web ACL $5, small ALB share, etc.).
- `high` — > $10/mo (NAT gateway $32, RDS instance, ElastiCache, idle Lambda provisioned concurrency, …).

### `Domain`
Use `internal` for resources not tied to a public domain (TF state buckets, GitHub OIDC providers, internal scheduling). Otherwise pick the most specific hostname the resource ultimately serves — subdomains are first-class (e.g. `dashboard.ffreis.com` rather than `ffreis.com`) so Cost Explorer can split spend per surface.

## Versioning

- **v1.x** — original schema (`Workspace` / `Service` / `Team` / …). Not consumed by any infra repo. Kept for reference.
- **v2.0.0** — current schema. Breaking change. Pin via `?ref=v2.0.0` until a v3 ships.

<!-- BEGIN_TF_DOCS -->
## Requirements

| Name | Version |
|------|---------|
| <a name="requirement_terraform"></a> [terraform](#requirement\_terraform) | >= 1.5.0, < 2.0.0 |

## Providers

No providers.

## Modules

No modules.

## Resources

No resources.

## Inputs

| Name | Description | Type | Default | Required |
|------|-------------|------|---------|:--------:|
| <a name="input_additional_tags"></a> [additional\_tags](#input\_additional\_tags) | Caller-specific tags to merge on top. Use sparingly — prefer adding a first-class variable here if the tag is reused. | `map(string)` | `{}` | no |
| <a name="input_backup_policy"></a> [backup\_policy](#input\_backup\_policy) | Backup policy: 'none', 'daily', 'weekly', 'pitr' (DDB point-in-time recovery), etc. | `string` | `"none"` | no |
| <a name="input_compliance_framework"></a> [compliance\_framework](#input\_compliance\_framework) | Compliance regime this resource is in scope for: 'none', 'lgpd', 'pci', 'hipaa', etc. | `string` | `"none"` | no |
| <a name="input_cost_center"></a> [cost\_center](#input\_cost\_center) | Per-product cost center for Cost Explorer grouping. Examples: 'flemming', 'petlook', 'ffreis-com', 'ffreis-website', 'platform', 'dashboard', 'ai-ask'. Do NOT use a single shared value (e.g. 'engineering') — it defeats the point of per-product budget visibility. | `string` | n/a | yes |
| <a name="input_data_classification"></a> [data\_classification](#input\_data\_classification) | Data sensitivity: 'public', 'internal', 'confidential', or 'restricted'. | `string` | `"internal"` | no |
| <a name="input_domain"></a> [domain](#input\_domain) | Public-facing domain (or subdomain) this resource serves. Cross-cuts Project (a shared stack may serve multiple domains). Subdomains are first-class so Cost Explorer can split spend per surface (e.g. dashboard vs. main site). | `string` | `"internal"` | no |
| <a name="input_environment"></a> [environment](#input\_environment) | Deployment environment: 'dev' or 'prod'. | `string` | n/a | yes |
| <a name="input_fixed_cost_tier"></a> [fixed\_cost\_tier](#input\_fixed\_cost\_tier) | Fixed monthly cost band: 'none' (pay-per-request only), 'low' (<$1/mo), 'medium' ($1-$10/mo), or 'high' (>$10/mo). Tag honestly — Cost Explorer queries depend on it. | `string` | `"none"` | no |
| <a name="input_layer"></a> [layer](#input\_layer) | Sub-component inside the stack (e.g. 'flemming-infra', 'email-forwarder', 'website'). | `string` | n/a | yes |
| <a name="input_lifecycle_state"></a> [lifecycle\_state](#input\_lifecycle\_state) | Resource lifecycle: 'production' (serving real users), 'development' (dev/staging), 'experiment' (short-lived spike), or 'legacy' (slated for deletion). Drives cleanup audits. | `string` | n/a | yes |
| <a name="input_managed_by"></a> [managed\_by](#input\_managed\_by) | What manages this resource: 'terraform' (default) or 'manual'. | `string` | `"terraform"` | no |
| <a name="input_owner"></a> [owner](#input\_owner) | Owning team or individual (e.g. 'felipefuhr'). | `string` | `"felipefuhr"` | no |
| <a name="input_project"></a> [project](#input\_project) | Product / project slug. Drives Cost Explorer per-product grouping. Examples: 'flemming', 'petlook', 'ffreis-website', 'platform-shared-infra'. | `string` | n/a | yes |
| <a name="input_repository"></a> [repository](#input\_repository) | Source repository URL (e.g. 'github.com/FelipeFuhr/ffreis-flemming-infra'). | `string` | `""` | no |
| <a name="input_stack"></a> [stack](#input\_stack) | Logical stack this resource belongs to (typically matches the project, but may group multiple projects). | `string` | n/a | yes |
| <a name="input_terraform_repo"></a> [terraform\_repo](#input\_terraform\_repo) | Name of the Terraform repo that owns this resource (e.g. 'ffreis-flemming-infra'). | `string` | n/a | yes |
| <a name="input_terraform_root"></a> [terraform\_root](#input\_terraform\_root) | Path inside the Terraform repo where root module lives (e.g. 'infra', 'stack'). | `string` | n/a | yes |
| <a name="input_terraform_version"></a> [terraform\_version](#input\_terraform\_version) | Terraform CLI version pinned by the caller (e.g. '1.9.8'). | `string` | `""` | no |

## Outputs

| Name | Description |
|------|-------------|
| <a name="output_cost_center"></a> [cost\_center](#output\_cost\_center) | CostCenter tag value. |
| <a name="output_environment"></a> [environment](#output\_environment) | Environment tag value. |
| <a name="output_project"></a> [project](#output\_project) | Project tag value (useful for name prefixes). |
| <a name="output_stack"></a> [stack](#output\_stack) | Stack tag value. |
| <a name="output_tags"></a> [tags](#output\_tags) | Complete tag map. Pass as `tags = module.tags.tags` to every other module, and as `provider "aws" { default_tags { tags = module.tags.tags } }` at the root. |
<!-- END_TF_DOCS -->