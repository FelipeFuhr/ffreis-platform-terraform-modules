variable "function_name" {
  description = "Lambda function name."
  type        = string
}

variable "description" {
  description = "Human-readable description of the function."
  type        = string
  default     = ""
}

variable "handler" {
  description = "Function entry point (e.g. 'index.handler' for Node.js, 'main' for Go)."
  type        = string
}

variable "runtime" {
  description = "Lambda runtime identifier (e.g. 'python3.12', 'nodejs22.x', 'provided.al2023')."
  type        = string
}

variable "filename" {
  description = "Path to the deployment package (zip). Mutually exclusive with image_uri and s3_bucket."
  type        = string
  default     = null
}

variable "s3_bucket" {
  description = "S3 bucket containing the deployment package. Must be set together with s3_key. Mutually exclusive with filename and image_uri."
  type        = string
  default     = null
}

variable "s3_key" {
  description = "S3 object key for the deployment package zip. Must be set together with s3_bucket."
  type        = string
  default     = null
}

variable "s3_object_version" {
  description = "S3 object version ID of the deployment package. Optional."
  type        = string
  default     = null
}

variable "image_uri" {
  description = "ECR image URI. Mutually exclusive with filename. Package type becomes 'Image'."
  type        = string
  default     = null
}

variable "source_code_hash" {
  description = "Base64-encoded SHA-256 hash of the package. Used to detect changes."
  type        = string
  default     = null
}

variable "memory_size" {
  description = "Lambda memory allocation in MB (128–10240)."
  type        = number
  default     = 128
}

variable "timeout" {
  description = "Function timeout in seconds (1–900)."
  type        = number
  default     = 30
}

variable "architectures" {
  description = "Instruction set architecture: ['x86_64'] or ['arm64']."
  type        = list(string)
  default     = ["arm64"]
}

variable "environment_variables" {
  description = "Map of environment variables passed to the function."
  type        = map(string)
  default     = {}
  sensitive   = true
}

variable "kms_key_arn" {
  description = "KMS key ARN for encrypting environment variables and X-Ray traces."
  type        = string
  default     = null
}

variable "layers" {
  description = "List of Lambda layer ARNs to attach (max 5)."
  type        = list(string)
  default     = []
}

variable "reserved_concurrent_executions" {
  description = "Reserved concurrency for this function. -1 = unreserved."
  type        = number
  default     = -1
}

# --- VPC ---
variable "vpc_subnet_ids" {
  description = "Subnet IDs for VPC-attached Lambda. Empty = no VPC attachment."
  type        = list(string)
  default     = []
}

variable "vpc_security_group_ids" {
  description = "Security group IDs for VPC-attached Lambda."
  type        = list(string)
  default     = []
}

# --- Dead-letter queue ---
variable "dead_letter_target_arn" {
  description = "ARN of an SQS queue or SNS topic for failed async invocations."
  type        = string
  default     = null
}

# --- IAM ---
variable "managed_policy_arns" {
  description = "Managed policy ARNs to attach to the execution role (in addition to AWSLambdaBasicExecutionRole)."
  type        = list(string)
  default     = []
}

variable "inline_policies" {
  description = "Map of inline policy name → JSON for the execution role."
  type        = map(string)
  default     = {}
}

variable "execution_role_arn" {
  description = "Use an existing IAM role ARN instead of creating one. When set, managed_policy_arns and inline_policies are ignored."
  type        = string
  default     = null
}

# --- CloudWatch Logs ---
variable "log_retention_days" {
  description = "CloudWatch log retention in days for /aws/lambda/<function_name>."
  type        = number
  default     = 365
}

variable "log_kms_key_arn" {
  description = "KMS key ARN for the Lambda CloudWatch log group."
  type        = string
  default     = null
}

# --- Event source mapping ---
variable "event_source_mappings" {
  description = <<-EOT
    Map of event source name → configuration (SQS, DynamoDB Streams, Kinesis, MSK).
  EOT
  type = map(object({
    event_source_arn                   = string
    batch_size                         = optional(number, 10)
    maximum_batching_window_in_seconds = optional(number, 0)
    starting_position                  = optional(string, null) # TRIM_HORIZON | LATEST | AT_TIMESTAMP
    enabled                            = optional(bool, true)
    bisect_batch_on_function_error     = optional(bool, false)
    maximum_retry_attempts             = optional(number, null)
    parallelization_factor             = optional(number, null)
    tumbling_window_in_seconds         = optional(number, null)
    function_response_types            = optional(list(string), [])
    filter_criteria = optional(list(object({
      pattern = string
    })), [])
  }))
  default = {}
}

variable "tags" {
  description = "Tags applied to all resources."
  type        = map(string)
  default     = {}
}
