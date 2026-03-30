variable "name" {
  description = "IAM role name."
  type        = string
}

variable "assume_role_policy" {
  description = "JSON trust policy document. Use aws_iam_policy_document data source."
  type        = string
}

variable "managed_policy_arns" {
  description = "List of managed IAM policy ARNs to attach to the role."
  type        = list(string)
  default     = []
}

variable "inline_policies" {
  description = "Map of inline policy name → JSON. Each entry creates one aws_iam_role_policy."
  type        = map(string)
  default     = {}
}

variable "max_session_duration" {
  description = "Maximum session duration in seconds (3600–43200)."
  type        = number
  default     = 3600

  validation {
    condition     = var.max_session_duration >= 3600 && var.max_session_duration <= 43200
    error_message = "max_session_duration must be between 3600 and 43200."
  }
}

variable "path" {
  description = "IAM path for the role."
  type        = string
  default     = "/"
}

variable "permissions_boundary" {
  description = "ARN of the permissions boundary policy. Leave null for no boundary."
  type        = string
  default     = null
}

variable "description" {
  description = "Human-readable description for the role."
  type        = string
  default     = ""
}

variable "force_detach_policies" {
  description = "Force-detach policies before destroying the role."
  type        = bool
  default     = false
}

variable "tags" {
  description = "Tags applied to all resources."
  type        = map(string)
  default     = {}
}
