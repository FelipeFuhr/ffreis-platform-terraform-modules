variable "enable" {
  description = "Enable the GuardDuty detector."
  type        = bool
  default     = true
}

variable "finding_publishing_frequency" {
  description = "How often to publish findings: 'FIFTEEN_MINUTES', 'ONE_HOUR', or 'SIX_HOURS'."
  type        = string
  default     = "ONE_HOUR"

  validation {
    condition     = contains(["FIFTEEN_MINUTES", "ONE_HOUR", "SIX_HOURS"], var.finding_publishing_frequency)
    error_message = "finding_publishing_frequency must be FIFTEEN_MINUTES, ONE_HOUR, or SIX_HOURS."
  }
}

variable "enable_s3_protection" {
  description = "Enable S3 data-event threat intelligence."
  type        = bool
  default     = true
}

variable "enable_eks_protection" {
  description = "Enable EKS audit log monitoring."
  type        = bool
  default     = false
}

variable "enable_malware_protection" {
  description = "Enable malware scanning for EC2 EBS volumes."
  type        = bool
  default     = false
}

variable "findings_s3_bucket" {
  description = "S3 bucket name to export findings to. null = no export."
  type        = string
  default     = null
}

variable "findings_kms_key_arn" {
  description = "KMS key ARN to encrypt exported findings."
  type        = string
  default     = null
}

variable "ipset_iplist_uri" {
  description = "S3 URI of a trusted IP list (e.g. 's3://bucket/trusted-ips.txt'). null = skip."
  type        = string
  default     = null
}

variable "tags" {
  description = "Tags applied to all resources."
  type        = map(string)
  default     = {}
}
