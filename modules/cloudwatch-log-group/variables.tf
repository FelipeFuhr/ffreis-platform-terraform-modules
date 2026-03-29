variable "name" {
  description = "CloudWatch Logs log group name."
  type        = string
}

variable "retention_in_days" {
  description = "Number of days to retain log events. 0 = never expire."
  type        = number
  default     = 365

  validation {
    condition = contains(
      [0, 1, 3, 5, 7, 14, 30, 60, 90, 120, 150, 180, 365, 400, 545, 731, 1096, 1827, 2192, 2557, 2922, 3288, 3653],
      var.retention_in_days
    )
    error_message = "retention_in_days must be a value accepted by CloudWatch Logs."
  }
}

variable "kms_key_arn" {
  description = "KMS key ARN for encrypting log data at rest. null = CloudWatch-managed encryption."
  type        = string
  default     = null
}

variable "skip_destroy" {
  description = "If true, the log group is not deleted on terraform destroy (useful for audit logs)."
  type        = bool
  default     = false
}

variable "tags" {
  description = "Tags applied to all resources."
  type        = map(string)
  default     = {}
}
