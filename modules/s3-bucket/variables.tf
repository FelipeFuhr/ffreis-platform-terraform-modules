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
