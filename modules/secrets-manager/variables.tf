variable "name" {
  description = "Secret name (or prefix when name_prefix is used)."
  type        = string
}

variable "use_name_prefix" {
  description = "Use var.name as a prefix (adds a unique suffix to avoid conflicts)."
  type        = bool
  default     = false
}

variable "description" {
  description = "Human-readable description of the secret."
  type        = string
  default     = ""
}

variable "kms_key_id" {
  description = "KMS key ARN/ID for encrypting the secret. null = AWS-managed key."
  type        = string
  default     = null
}

variable "secret_string" {
  description = "The secret value as a string (plain text or JSON). Mutually exclusive with secret_binary."
  type        = string
  default     = null
  sensitive   = true
}

variable "secret_binary" {
  description = "The secret value as base64-encoded bytes. Mutually exclusive with secret_string."
  type        = string
  default     = null
  sensitive   = true
}

variable "recovery_window_in_days" {
  description = "Number of days before a secret is permanently deleted after deletion (0 = immediate, 7–30)."
  type        = number
  default     = 30

  validation {
    condition     = var.recovery_window_in_days == 0 || (var.recovery_window_in_days >= 7 && var.recovery_window_in_days <= 30)
    error_message = "recovery_window_in_days must be 0 (force delete) or between 7 and 30."
  }
}

variable "enable_rotation" {
  description = "Enable automatic secret rotation."
  type        = bool
  default     = false
}

variable "rotation_lambda_arn" {
  description = "ARN of the Lambda function that handles rotation. Required when enable_rotation = true."
  type        = string
  default     = null
}

variable "rotation_automatically_after_days" {
  description = "Rotate the secret every N days."
  type        = number
  default     = 30
}

variable "policy" {
  description = "JSON resource policy. null = no resource policy."
  type        = string
  default     = null
}

variable "tags" {
  description = "Tags applied to all resources."
  type        = map(string)
  default     = {}
}
