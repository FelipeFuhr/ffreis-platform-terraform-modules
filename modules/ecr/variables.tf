variable "name" {
  description = "ECR repository name."
  type        = string
}

variable "scan_on_push" {
  description = "Scan images for vulnerabilities on push."
  type        = bool
  default     = true
}

variable "encryption_type" {
  description = "Encryption type for the repository. Must be 'KMS' to satisfy compliance checks."
  type        = string
  default     = "KMS"

  validation {
    condition     = var.encryption_type == "KMS"
    error_message = "encryption_type must be 'KMS'."
  }
}

variable "kms_key_arn" {
  description = "KMS key ARN for KMS encryption. Required when encryption_type = 'KMS'."
  type        = string
  default     = null
}

variable "lifecycle_policy" {
  description = "JSON ECR lifecycle policy. null = AWS default (keep all images)."
  type        = string
  default     = null
}

variable "untagged_image_expiry_days" {
  description = "Expire untagged images after this many days. 0 = disabled. Ignored if lifecycle_policy is set."
  type        = number
  default     = 14
}

variable "keep_image_count" {
  description = "Keep the N most recent tagged images. 0 = keep all. Ignored if lifecycle_policy is set."
  type        = number
  default     = 30
}

variable "repository_policy" {
  description = "JSON ECR repository resource policy (cross-account access). null = private only."
  type        = string
  default     = null
}

variable "force_delete" {
  description = "Allow Terraform to delete the repository even when it contains images."
  type        = bool
  default     = false
}

variable "tags" {
  description = "Tags applied to all resources."
  type        = map(string)
  default     = {}
}
