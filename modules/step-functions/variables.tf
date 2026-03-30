variable "name" {
  description = "State machine name."
  type        = string
}

variable "type" {
  description = "State machine type: 'STANDARD' (long-running, exactly-once) or 'EXPRESS' (high-throughput, at-least-once)."
  type        = string
  default     = "STANDARD"

  validation {
    condition     = contains(["STANDARD", "EXPRESS"], var.type)
    error_message = "type must be 'STANDARD' or 'EXPRESS'."
  }
}

variable "definition" {
  description = "Amazon States Language JSON definition of the state machine."
  type        = string
}

variable "role_arn" {
  description = "IAM role ARN for the state machine. Leave null to create one."
  type        = string
  default     = null
}

variable "role_inline_policies" {
  description = "Map of inline policy name → JSON for the auto-created state machine role."
  type        = map(string)
  default     = {}
}

variable "role_managed_policy_arns" {
  description = "Managed policy ARNs for the auto-created state machine role."
  type        = list(string)
  default     = []
}

variable "enable_xray_tracing" {
  description = "Enable X-Ray tracing."
  type        = bool
  default     = true
}

variable "log_level" {
  description = "Execution logging level: 'OFF', 'ERROR', 'FATAL', or 'ALL'."
  type        = string
  default     = "ERROR"

  validation {
    condition     = contains(["OFF", "ERROR", "FATAL", "ALL"], var.log_level)
    error_message = "log_level must be OFF, ERROR, FATAL, or ALL."
  }
}

variable "log_include_execution_data" {
  description = "Include input/output data in execution logs. Disable if data is sensitive."
  type        = bool
  default     = false
}

variable "log_retention_days" {
  description = "CloudWatch log retention for execution logs."
  type        = number
  default     = 365
}

variable "log_kms_key_arn" {
  description = "KMS key ARN for the execution log group."
  type        = string
  default     = null
}

variable "tags" {
  description = "Tags applied to all resources."
  type        = map(string)
  default     = {}
}
