variable "domain_name" {
  description = "SageMaker Studio domain name."
  type        = string
}

variable "auth_mode" {
  description = "Authentication mode: 'IAM' or 'SSO'."
  type        = string
  default     = "IAM"

  validation {
    condition     = contains(["IAM", "SSO"], var.auth_mode)
    error_message = "auth_mode must be 'IAM' or 'SSO'."
  }
}

variable "vpc_id" {
  description = "VPC ID for the SageMaker domain."
  type        = string
}

variable "subnet_ids" {
  description = "Subnet IDs (private subnets recommended) for SageMaker Studio."
  type        = list(string)
}

variable "app_network_access_type" {
  description = "Network access type: 'PublicInternetOnly' or 'VpcOnly'. VpcOnly is recommended."
  type        = string
  default     = "VpcOnly"

  validation {
    condition     = contains(["PublicInternetOnly", "VpcOnly"], var.app_network_access_type)
    error_message = "app_network_access_type must be 'PublicInternetOnly' or 'VpcOnly'."
  }
}

variable "kms_key_id" {
  description = "KMS key ARN for encrypting SageMaker EFS and EBS volumes."
  type        = string
  default     = null
}

variable "default_user_settings" {
  description = "Default user settings for new Studio users."
  type = object({
    execution_role = string # IAM role ARN used by Studio notebooks.
    security_groups = optional(list(string), [])
    sharing_settings = optional(object({
      notebook_output_option = optional(string, "Disabled")
      s3_kms_key_id          = optional(string, null)
      s3_output_path         = optional(string, null)
    }), null)
  })
}

variable "user_profiles" {
  description = "Map of user profile name → configuration. Each entry creates an aws_sagemaker_user_profile."
  type = map(object({
    execution_role  = optional(string, null)  # Override the domain default if needed.
    security_groups = optional(list(string), [])
    tags            = optional(map(string), {})
  }))
  default = {}
}

variable "tags" {
  description = "Tags applied to all resources."
  type        = map(string)
  default     = {}
}
