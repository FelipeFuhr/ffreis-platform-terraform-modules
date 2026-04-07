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
  description = "Optional encryption type for the repository. Null defaults to 'AES256' for zero fixed cost unless kms_key_arn is set, in which case 'KMS' is used."
  type        = string
  default     = null

  validation {
    condition     = var.encryption_type == null || contains(["AES256", "KMS"], var.encryption_type)
    error_message = "encryption_type must be null, 'AES256', or 'KMS'."
  }

  validation {
    condition     = var.kms_key_arn == null || var.encryption_type == null || var.encryption_type == "KMS"
    error_message = "When kms_key_arn is set, encryption_type must be null or 'KMS'."
  }
}

variable "kms_key_arn" {
  description = "Optional customer-managed KMS key ARN for repository encryption. Null keeps the default zero-fixed-cost encryption mode."
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
