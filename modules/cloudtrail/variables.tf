variable "name" {
  description = "CloudTrail trail name."
  type        = string
}

variable "s3_bucket_name" {
  description = "S3 bucket to receive CloudTrail log files. The bucket must already exist."
  type        = string
}

variable "s3_key_prefix" {
  description = "S3 key prefix for CloudTrail log files. Defaults to the trail name."
  type        = string
  default     = ""
}

variable "is_multi_region_trail" {
  description = "Enable the trail in all regions. Recommended for org-level auditing."
  type        = bool
  default     = true
}

variable "include_global_service_events" {
  description = "Capture IAM, STS, and other global-scope API calls."
  type        = bool
  default     = true
}

variable "enable_log_file_validation" {
  description = "Enable CloudTrail digest files for log integrity validation."
  type        = bool
  default     = true
}

variable "kms_key_arn" {
  description = "KMS key ARN for encrypting CloudTrail logs in S3. Required — CloudTrail must be encrypted at rest."
  type        = string
}

variable "cloudwatch_logs_retention_days" {
  description = "Retention period for the CloudWatch Logs log group."
  type        = number
  default     = 365
}

variable "cloudwatch_logs_kms_key_arn" {
  description = "KMS key ARN for the CloudWatch Logs log group. null = CW-managed."
  type        = string
  default     = null
}

variable "sns_kms_key_arn" {
  description = "Optional customer-managed KMS key ARN for encrypting the CloudTrail SNS topic. Null uses the AWS-managed SNS key with no fixed monthly CMK cost."
  type        = string
  default     = null
}

variable "event_selectors" {
  description = <<-EOT
    List of event selectors for data events (e.g., S3 object-level events).
    See https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/cloudtrail#event_selector
  EOT
  type = list(object({
    read_write_type           = string # "ReadOnly" | "WriteOnly" | "All"
    include_management_events = bool
    data_resources = list(object({
      type   = string
      values = list(string)
    }))
  }))
  default = []
}

variable "tags" {
  description = "Tags applied to all resources."
  type        = map(string)
  default     = {}
}
