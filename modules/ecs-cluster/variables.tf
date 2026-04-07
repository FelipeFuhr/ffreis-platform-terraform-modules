variable "name" {
  description = "ECS cluster name."
  type        = string
}

variable "enable_container_insights" {
  description = "Enable CloudWatch Container Insights for the cluster."
  type        = bool
  default     = true
}

variable "capacity_providers" {
  description = "Capacity providers to associate with the cluster. Defaults to Fargate and Fargate Spot."
  type        = list(string)
  default     = ["FARGATE", "FARGATE_SPOT"]
}

variable "default_capacity_provider_strategy" {
  description = "Default capacity provider strategy applied to services that don't specify one."
  type = list(object({
    capacity_provider = string
    weight            = optional(number, 1)
    base              = optional(number, 0)
  }))
  default = [
    { capacity_provider = "FARGATE", weight = 1, base = 1 },
    { capacity_provider = "FARGATE_SPOT", weight = 4, base = 0 },
  ]
}

variable "execute_command_kms_key_arn" {
  description = "Optional customer-managed KMS key ARN for encrypting ECS Exec session data and audit logs. Null uses the default AWS-managed encryption path with no fixed monthly CMK cost."
  type        = string
  default     = null
}

variable "execute_command_log_group_name" {
  description = "CloudWatch log group name for ECS Exec audit logs."
  type        = string
  default     = null
}

variable "execute_command_s3_bucket" {
  description = "S3 bucket name for ECS Exec audit logs."
  type        = string
  default     = null
}

variable "tags" {
  description = "Tags applied to all resources."
  type        = map(string)
  default     = {}
}
