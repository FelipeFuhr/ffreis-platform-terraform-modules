variable "description" {
  description = "Human-readable description for the KMS key."
  type        = string
}

variable "alias" {
  description = "KMS key alias (without the 'alias/' prefix)."
  type        = string
}

variable "deletion_window_in_days" {
  description = "Number of days after which the key is deleted following a deletion request (7–30)."
  type        = number
  default     = 30

  validation {
    condition     = var.deletion_window_in_days >= 7 && var.deletion_window_in_days <= 30
    error_message = "deletion_window_in_days must be between 7 and 30."
  }
}

variable "enable_key_rotation" {
  description = "Rotate the key material annually. Strongly recommended."
  type        = bool
  default     = true
}

variable "multi_region" {
  description = "Create a multi-Region primary key."
  type        = bool
  default     = false
}

variable "policy" {
  description = "JSON IAM key policy. When null the default AWS key policy is used."
  type        = string
  default     = null
}

variable "additional_principals" {
  description = "List of IAM principal ARNs to grant Decrypt/GenerateDataKey in addition to the key owner."
  type        = list(string)
  default     = []
}

variable "tags" {
  description = "Tags applied to all resources."
  type        = map(string)
  default     = {}
}
