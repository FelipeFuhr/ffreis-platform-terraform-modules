variable "name" {
  description = "EventBridge rule name."
  type        = string
}

variable "description" {
  description = "Human-readable description."
  type        = string
  default     = ""
}

variable "event_bus_name" {
  description = "Name or ARN of the event bus. Defaults to the default event bus."
  type        = string
  default     = "default"
}

variable "schedule_expression" {
  description = "Cron or rate expression (e.g. 'rate(5 minutes)', 'cron(0 12 * * ? *)'). Mutually exclusive with event_pattern."
  type        = string
  default     = null
}

variable "event_pattern" {
  description = "JSON event pattern. Mutually exclusive with schedule_expression."
  type        = string
  default     = null
}

variable "state" {
  description = "Rule state: 'ENABLED' or 'DISABLED'."
  type        = string
  default     = "ENABLED"

  validation {
    condition     = contains(["ENABLED", "DISABLED"], var.state)
    error_message = "state must be 'ENABLED' or 'DISABLED'."
  }
}

variable "targets" {
  description = <<-EOT
    Map of target name → configuration.
    arn: ARN of the target (Lambda, SQS, SNS, Kinesis, Step Functions, etc.).
    input:       Literal JSON string sent as event. Mutually exclusive with input_path/input_transformer.
    input_path:  JSONPath string to extract part of the matched event.
    input_transformer: Transform matched events (supports input_paths_map + input_template).
    dead_letter_arn: SQS queue ARN for failed deliveries.
    retry_policy: Optional retry configuration.
  EOT
  type = map(object({
    arn  = string
    role_arn = optional(string, null)
    input    = optional(string, null)
    input_path = optional(string, null)
    input_transformer = optional(object({
      input_paths    = map(string)
      input_template = string
    }), null)
    dead_letter_arn = optional(string, null)
    retry_policy = optional(object({
      maximum_event_age_in_seconds = number
      maximum_retry_attempts       = number
    }), null)
    sqs_message_group_id = optional(string, null)
  }))
  default = {}
}

variable "tags" {
  description = "Tags applied to all resources."
  type        = map(string)
  default     = {}
}
