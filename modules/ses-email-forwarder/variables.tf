variable "domain_name" {
  description = "Domain to receive email for (e.g. ffreis.com). Must already have an active SES domain identity."
  type        = string
}

variable "email_bucket_kms_key_arn" {
  description = "Optional customer-managed KMS key ARN for inbound email bucket encryption. Null uses the AWS-managed S3 KMS key with no fixed monthly CMK cost."
  type        = string
  default     = null
}

variable "s3_access_logs_bucket_name" {
  description = "Central S3 bucket name that receives access logs for the inbound email bucket."
  type        = string

  validation {
    condition     = trimspace(var.s3_access_logs_bucket_name) != ""
    error_message = "s3_access_logs_bucket_name must be a non-empty bucket name."
  }
}

variable "s3_access_logs_prefix" {
  description = "Prefix for inbound email bucket access logs in the central logging bucket. Empty uses a module default."
  type        = string
  default     = ""
}

variable "hosted_zone_id" {
  description = "Route 53 hosted zone ID for the domain. Used to create the MX record pointing to SES inbound."
  type        = string
}

variable "forwarding_aliases" {
  description = "Map of lower-case local-part → destination email address. Use \"*\" as a catch-all key. Example: { infrastructure = \"me@gmail.com\", felipefuhrdosreis = \"me@gmail.com\" }"
  type        = map(string)
  validation {
    condition     = alltrue([for v in values(var.forwarding_aliases) : can(regex("^[a-zA-Z0-9._%+-]+@[a-zA-Z0-9.-]+\\.[a-zA-Z]{2,}$", v))])
    error_message = "All destination values must be valid email addresses."
  }
}

variable "from_email" {
  description = "SES-verified sender address used when re-sending forwarded mail (e.g. forwarding@ffreis.com). Must be within the verified domain."
  type        = string
  validation {
    condition     = can(regex("^[a-zA-Z0-9._%+-]+@[a-zA-Z0-9.-]+\\.[a-zA-Z]{2,}$", var.from_email))
    error_message = "Must be a valid email address."
  }
}

variable "email_bucket_name" {
  description = "S3 bucket name for storing raw inbound emails. Must be globally unique."
  type        = string
}

variable "email_key_prefix" {
  description = "S3 key prefix (no trailing slash) where SES stores raw emails."
  type        = string
  default     = "emails"

  validation {
    condition     = var.email_key_prefix == trimsuffix(var.email_key_prefix, "/")
    error_message = "email_key_prefix must not end with a trailing slash."
  }
}

variable "rule_set_name" {
  description = "SES receipt rule set name. This rule set will be set as the active one in the account when activate_rule_set is true."
  type        = string
  default     = "default-rule-set"
}

variable "activate_rule_set" {
  description = "Whether to set this receipt rule set as the active one in the account. Activating a rule set is account-wide and will replace any currently active rule set in the region."
  type        = bool
  default     = true
}

variable "log_retention_days" {
  description = "CloudWatch log retention for the forwarder Lambda."
  type        = number
  default     = 365

  validation {
    condition     = var.log_retention_days >= 365
    error_message = "log_retention_days must be at least 365 days to satisfy log retention requirements."
  }
}

variable "log_kms_key_arn" {
  description = "Optional customer-managed KMS key ARN for the email forwarder CloudWatch log group. Null uses the default CloudWatch Logs encryption with no fixed monthly CMK cost."
  type        = string
  default     = null
}

variable "tags" {
  description = "Tags applied to all resources."
  type        = map(string)
  default     = {}
}
