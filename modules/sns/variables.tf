variable "name" {
  description = "SNS topic name. For FIFO topics must end in '.fifo'."
  type        = string
}

variable "fifo_topic" {
  description = "Create a FIFO topic."
  type        = bool
  default     = false
}

variable "content_based_deduplication" {
  description = "Enable content-based deduplication (FIFO topics only)."
  type        = bool
  default     = false
}

variable "display_name" {
  description = "Display name used in SMS messages and email subjects."
  type        = string
  default     = ""
}

variable "kms_master_key_id" {
  description = "KMS key ARN/alias for SSE. Use 'alias/aws/sns' for the AWS-managed key."
  type        = string
  default     = "alias/aws/sns"
}

variable "policy" {
  description = "JSON topic access policy. null = AWS default (account-only)."
  type        = string
  default     = null
}

variable "delivery_policy" {
  description = "JSON HTTP/HTTPS delivery retry policy."
  type        = string
  default     = null
}

variable "subscriptions" {
  description = <<-EOT
    Map of subscription name → configuration.
    protocol: email | email-json | http | https | lambda | sqs | sms | firehose
    endpoint: ARN, URL, or phone number depending on the protocol.
    filter_policy: optional JSON attribute filter.
  EOT
  type = map(object({
    protocol                        = string
    endpoint                        = string
    raw_message_delivery            = optional(bool, false)
    filter_policy                   = optional(string, null)
    filter_policy_scope             = optional(string, "MessageAttributes")
    confirmation_timeout_in_minutes = optional(number, 1)
    endpoint_auto_confirms          = optional(bool, false)
  }))
  default = {}
}

variable "tags" {
  description = "Tags applied to all resources."
  type        = map(string)
  default     = {}
}
