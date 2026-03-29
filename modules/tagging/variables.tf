# ---------------------------------------------------------------------------
# Required cost-allocation and ownership tags.
# Pass the output of this module as `tags` to every other module.
# All tags are validated so nothing accidentally slips through unset.
# ---------------------------------------------------------------------------

variable "workspace" {
  description = "Terraform workspace / environment this resource belongs to (e.g. 'management', 'ml', 'db', 'prod', 'staging')."
  type        = string
}

variable "service" {
  description = "Service or application name (e.g. 'myapp-api', 'data-pipeline', 'sagemaker-studio')."
  type        = string
}

variable "team" {
  description = "Owning team (e.g. 'platform', 'ml', 'backend', 'data'). Used to split billing by team."
  type        = string
}

variable "cost_center" {
  description = "Cost center code for billing allocation."
  type        = string
}

variable "managed_by" {
  description = "What manages this resource: 'terraform' (default) or 'manual'."
  type        = string
  default     = "terraform"
}

variable "repository" {
  description = "Source repository URL or name (e.g. 'github.com/ffreis/platform-bootstrap')."
  type        = string
  default     = ""
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

variable "additional_tags" {
  description = "Additional tags to merge in (caller-specific, not required by the baseline)."
  type        = map(string)
  default     = {}
}
