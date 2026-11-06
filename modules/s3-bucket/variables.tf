variable "bucket" {
  description = "S3 bucket name."
  type        = string
}

variable "versioning_enabled" {
  description = "Enable S3 Versioning. Recommended true for state/artifact buckets."
  type        = bool
  default     = true
}

variable "sse_algorithm" {
  description = "Server-side encryption algorithm. 'AES256' or 'aws:kms'."
  type        = string
  default     = "aws:kms"

  validation {
    condition     = contains(["AES256", "aws:kms"], var.sse_algorithm)
    error_message = "sse_algorithm must be 'AES256' or 'aws:kms'."
  }
}

variable "kms_master_key_id" {
  description = "KMS key ARN/ID for aws:kms SSE. Required when sse_algorithm = 'aws:kms'."
  type        = string
  default     = null
}

variable "force_destroy" {
  description = "Allow Terraform to destroy the bucket even when it contains objects."
  type        = bool
  default     = false
}

variable "lifecycle_rules" {
  description = <<-EOT
    Optional lifecycle rules. Example:
      [{
        id      = "expire-old-versions"
        enabled = true
        noncurrent_version_expiration_days = 90
      }]
  EOT
  type = list(object({
    id      = string
    enabled = bool
    # Expiration of current objects (days). null = skip.
    expiration_days = optional(number, null)
    # Expiration of noncurrent versions (days). null = skip.
    noncurrent_version_expiration_days = optional(number, null)
  }))
  default = []
}

variable "abort_incomplete_multipart_upload_days" {
  description = "Days after initiation to abort incomplete multipart uploads. Set to 0 to disable."
  type        = number
  default     = 7
}

variable "logging_target_bucket" {
  description = "S3 bucket to receive access logs. Leave empty to skip access logging; pass an empty string for the logging bucket itself to break the circular dependency."
  type        = string
  default     = ""
}

variable "logging_target_prefix" {
  description = "Log prefix when access logging is enabled."
  type        = string
  default     = ""
}

variable "object_lock_enabled" {
  description = "Enable S3 Object Lock (WORM). Cannot be disabled after creation."
  type        = bool
  default     = false
}

variable "object_lock_mode" {
  description = "Object Lock retention mode when object_lock_enabled = true: 'GOVERNANCE' or 'COMPLIANCE'."
  type        = string
  default     = "GOVERNANCE"

  validation {
    condition     = contains(["GOVERNANCE", "COMPLIANCE"], var.object_lock_mode)
    error_message = "object_lock_mode must be 'GOVERNANCE' or 'COMPLIANCE'."
  }
}

variable "object_lock_days" {
  description = "Default Object Lock retention in days. 0 uses years instead."
  type        = number
  default     = 0
}

variable "object_lock_years" {
  description = "Default Object Lock retention in years. Used when object_lock_days = 0."
  type        = number
  default     = 1
}

variable "intelligent_tiering" {
  description = "Enable S3 Intelligent-Tiering to automatically move objects to cheaper tiers."
  type        = bool
  default     = false
}

variable "tags" {
  description = "Tags applied to all resources."
  type        = map(string)
  default     = {}
}

variable "prevent_destroy" {
  description = "Set true in production to block accidental resource destruction. Uses a terraform_data guard — to destroy the module, set this to false and apply first."
  type        = bool
  default     = false
}

variable "manage_bucket_policy" {
  description = <<-EOT
    Whether this module owns the bucket policy. Default true: the module
    attaches a TLS-only policy denying any non-HTTPS request.

    Set false ONLY when the caller must own the policy because the bucket needs
    additional statements — most commonly a CloudFront OAC read grant. A bucket
    has exactly ONE policy document, so a caller that attaches its own while
    this module also attaches one creates two resources contending for a single
    object: whichever applies last wins and the other's statements disappear,
    then come back on the next apply. The oscillation is silent, and it
    surfaces only as the CDN origin intermittently losing read access.

    Opting out does NOT mean losing the control: the TLS statement is exposed
    as the `tls_enforce_policy_json` output. Merge it into the caller's
    document via `override_policy_documents` so HTTPS stays enforced.
  EOT
  type        = bool
  default     = true
}
