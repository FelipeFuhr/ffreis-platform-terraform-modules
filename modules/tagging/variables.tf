variable "project" {
  description = "Product / project slug. Drives Cost Explorer per-product grouping. Examples: 'flemming', 'petlook', 'ffreis-website', 'platform-shared-infra'."
  type        = string
}

variable "environment" {
  description = "Deployment environment: 'dev' or 'prod'."
  type        = string

  validation {
    condition     = contains(["dev", "prod"], var.environment)
    error_message = "environment must be 'dev' or 'prod'."
  }
}

variable "stack" {
  description = "Logical stack this resource belongs to (typically matches the project, but may group multiple projects)."
  type        = string
}

variable "layer" {
  description = "Sub-component inside the stack (e.g. 'flemming-infra', 'email-forwarder', 'website')."
  type        = string
}

variable "terraform_repo" {
  description = "Name of the Terraform repo that owns this resource (e.g. 'ffreis-flemming-infra')."
  type        = string
}

variable "terraform_root" {
  description = "Path inside the Terraform repo where root module lives (e.g. 'infra', 'stack')."
  type        = string
}

variable "terraform_version" {
  description = "Terraform CLI version pinned by the caller (e.g. '1.9.8')."
  type        = string
  default     = ""
}

variable "cost_center" {
  description = "Per-product cost center for Cost Explorer grouping. Examples: 'flemming', 'petlook', 'ffreis-com', 'ffreis-website', 'platform', 'dashboard', 'ai-ask'. Do NOT use a single shared value (e.g. 'engineering') — it defeats the point of per-product budget visibility."
  type        = string
}

variable "owner" {
  description = "Owning team or individual (e.g. 'felipefuhr')."
  type        = string
  default     = "felipefuhr"
}

variable "managed_by" {
  description = "What manages this resource: 'terraform' (default) or 'manual'."
  type        = string
  default     = "terraform"
}

variable "repository" {
  description = "Source repository URL (e.g. 'github.com/FelipeFuhr/ffreis-flemming-infra')."
  type        = string
  default     = ""
}

variable "compliance_framework" {
  description = "Compliance regime this resource is in scope for: 'none', 'lgpd', 'pci', 'hipaa', etc."
  type        = string
  default     = "none"
}

variable "data_classification" {
  description = "Data sensitivity: 'public', 'internal', 'confidential', or 'restricted'."
  type        = string
  default     = "internal"

  validation {
    condition     = contains(["public", "internal", "confidential", "restricted"], var.data_classification)
    error_message = "data_classification must be public, internal, confidential, or restricted."
  }
}

variable "backup_policy" {
  description = "Backup policy: 'none', 'daily', 'weekly', 'pitr' (DDB point-in-time recovery), etc."
  type        = string
  default     = "none"
}

variable "lifecycle_state" {
  description = "Resource lifecycle: 'production' (serving real users), 'development' (dev/staging), 'experiment' (short-lived spike), or 'legacy' (slated for deletion). Drives cleanup audits."
  type        = string

  validation {
    condition     = contains(["production", "development", "experiment", "legacy"], var.lifecycle_state)
    error_message = "lifecycle_state must be production, development, experiment, or legacy."
  }
}

variable "fixed_cost_tier" {
  description = "Fixed monthly cost band: 'none' (pay-per-request only), 'low' (<$1/mo), 'medium' ($1-$10/mo), or 'high' (>$10/mo). Tag honestly — Cost Explorer queries depend on it."
  type        = string
  default     = "none"

  validation {
    condition     = contains(["none", "low", "medium", "high"], var.fixed_cost_tier)
    error_message = "fixed_cost_tier must be none, low, medium, or high."
  }
}

variable "domain" {
  description = "Public-facing domain (or subdomain) this resource serves. Cross-cuts Project (a shared stack may serve multiple domains). Subdomains are first-class so Cost Explorer can split spend per surface (e.g. dashboard vs. main site)."
  type        = string
  default     = "internal"

  validation {
    condition = contains([
      "flemming.com.br",
      "ffreis.com",
      "petlook.ai",
      "petlook.app",
      "dashboard.ffreis.com",
      "uxstoryteller.ffreis.com",
      "pocketworldarcade.ffreis.com",
      "pocketworldarcade.app",
      "heavyheater.ffreis.com",
      "internal",
    ], var.domain)
    error_message = "domain must be one of: flemming.com.br, ffreis.com, petlook.ai, petlook.app, dashboard.ffreis.com, uxstoryteller.ffreis.com, pocketworldarcade.ffreis.com, pocketworldarcade.app, heavyheater.ffreis.com, internal."
  }
}

variable "additional_tags" {
  description = "Caller-specific tags to merge on top. Use sparingly — prefer adding a first-class variable here if the tag is reused."
  type        = map(string)
  default     = {}
}
