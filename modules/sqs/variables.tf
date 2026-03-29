variable "name" {
  description = "SQS queue name. For FIFO queues must end in '.fifo'."
  type        = string
}

variable "fifo_queue" {
  description = "Create a FIFO queue."
  type        = bool
  default     = false
}

variable "content_based_deduplication" {
  description = "Enable content-based deduplication (FIFO queues only)."
  type        = bool
  default     = false
}

variable "visibility_timeout_seconds" {
  description = "Visibility timeout in seconds (0–43200). Should exceed the consumer processing time."
  type        = number
  default     = 30
}

variable "message_retention_seconds" {
  description = "Time a message is retained in the queue (60–1209600 seconds, default 4 days)."
  type        = number
  default     = 345600
}

variable "max_message_size" {
  description = "Maximum message size in bytes (1024–262144)."
  type        = number
  default     = 262144
}

variable "delay_seconds" {
  description = "Delivery delay in seconds (0–900)."
  type        = number
  default     = 0
}

variable "receive_wait_time_seconds" {
  description = "Long-poll wait time in seconds (0–20). 20 is recommended to reduce empty-receive costs."
  type        = number
  default     = 20
}

variable "kms_master_key_id" {
  description = "KMS key ARN/alias for SSE-KMS. null = create a customer-managed key."
  type        = string
  default     = null
}

variable "kms_data_key_reuse_period_seconds" {
  description = "How long (seconds) SQS reuses a data key before requesting a new one (60–86400)."
  type        = number
  default     = 300
}

variable "create_dlq" {
  description = "Create a Dead-Letter Queue and configure the redrive policy."
  type        = bool
  default     = true
}

variable "dlq_message_retention_seconds" {
  description = "Message retention on the DLQ (seconds)."
  type        = number
  default     = 1209600 # 14 days
}

variable "max_receive_count" {
  description = "Number of times a message is delivered before being moved to the DLQ."
  type        = number
  default     = 5
}

variable "policy" {
  description = "JSON queue resource policy. null = no custom policy."
  type        = string
  default     = null
}

variable "tags" {
  description = "Tags applied to all resources."
  type        = map(string)
  default     = {}
}
