variable "name" {
  description = "ECR repository name."
  type        = string
}

variable "image_tag_mutability" {
  description = "Tag mutability: 'MUTABLE' or 'IMMUTABLE'. Immutable prevents overwriting existing tags."
  type        = string
  default     = "IMMUTABLE"

  validation {
    condition     = contains(["MUTABLE", "IMMUTABLE"], var.image_tag_mutability)
    error_message = "image_tag_mutability must be 'MUTABLE' or 'IMMUTABLE'."
  }
}

variable "scan_on_push" {
  description = "Scan images for vulnerabilities on push."
  type        = bool
  default     = true
}

variable "encryption_type" {
  description = "Encryption type: 'AES256' (AWS-managed) or 'KMS' (customer-managed)."
  type        = string
  default     = "AES256"

  validation {
    condition     = contains(["AES256", "KMS"], var.encryption_type)
    error_message = "encryption_type must be 'AES256' or 'KMS'."
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
