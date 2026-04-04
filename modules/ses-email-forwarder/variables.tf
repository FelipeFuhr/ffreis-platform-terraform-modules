variable "domain_name" {
  description = "Domain to receive email for (e.g. ffreis.com). Must already have an active SES domain identity."
  type        = string
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
}

variable "rule_set_name" {
  description = "SES receipt rule set name. This rule set will be set as the active one in the account."
  type        = string
  default     = "default-rule-set"
}

variable "log_retention_days" {
  description = "CloudWatch log retention for the forwarder Lambda."
  type        = number
  default     = 30
}

variable "tags" {
  description = "Tags applied to all resources."
  type        = map(string)
  default     = {}
}
