variable "cluster_id" {
  description = "ElastiCache replication group ID (max 40 chars, lowercase alphanumeric and hyphens)."
  type        = string
}

variable "description" {
  description = "Human-readable description for the replication group."
  type        = string
}

variable "node_type" {
  description = "ElastiCache node type (e.g. 'cache.t4g.micro', 'cache.r7g.large')."
  type        = string
}

variable "engine_version" {
  description = "Redis engine version (e.g. '7.1')."
  type        = string
  default     = "7.1"
}

variable "num_cache_clusters" {
  description = "Number of cache nodes in the replication group (1 = no replica, 2+ = with replica)."
  type        = number
  default     = 2
}

variable "automatic_failover_enabled" {
  description = "Enable automatic failover. Requires num_cache_clusters >= 2."
  type        = bool
  default     = true
}

variable "multi_az_enabled" {
  description = "Enable Multi-AZ support."
  type        = bool
  default     = true
}

variable "port" {
  description = "Redis port."
  type        = number
  default     = 6379
}

variable "subnet_group_name" {
  description = "ElastiCache subnet group name. The subnets must be in the same VPC as the security groups."
  type        = string
}

variable "security_group_ids" {
  description = "Security group IDs to associate with the cluster."
  type        = list(string)
}

variable "at_rest_encryption_enabled" {
  description = "Enable encryption at rest."
  type        = bool
  default     = true
}

variable "kms_key_id" {
  description = "KMS key ARN for at-rest encryption. null = ElastiCache-managed key."
  type        = string
  default     = null
}

variable "transit_encryption_enabled" {
  description = "Enable TLS in-transit encryption."
  type        = bool
  default     = true
}

variable "transit_encryption_mode" {
  description = "TLS mode: 'required' (enforce TLS) or 'preferred' (allow plaintext fallback)."
  type        = string
  default     = "required"

  validation {
    condition     = contains(["required", "preferred"], var.transit_encryption_mode)
    error_message = "transit_encryption_mode must be 'required' or 'preferred'."
  }
}

variable "auth_token" {
  description = "AUTH token (password) for Redis. Required when transit_encryption_enabled = true."
  type        = string
  default     = null
  sensitive   = true
}

variable "parameter_group_name" {
  description = "Parameter group name. null = engine default."
  type        = string
  default     = null
}

variable "apply_immediately" {
  description = "Apply changes immediately."
  type        = bool
  default     = false
}

variable "maintenance_window" {
  description = "Preferred maintenance window (e.g. 'sun:04:00-sun:05:00')."
  type        = string
  default     = "sun:04:00-sun:05:00"
}

variable "snapshot_retention_limit" {
  description = "Number of days to retain automatic snapshots (0–35). 0 = disabled."
  type        = number
  default     = 7
}

variable "snapshot_window" {
  description = "Daily snapshot window (e.g. '03:00-04:00'). Must not overlap maintenance_window."
  type        = string
  default     = "03:00-04:00"
}

variable "auto_minor_version_upgrade" {
  description = "Automatically apply minor Redis upgrades."
  type        = bool
  default     = true
}

variable "notification_topic_arn" {
  description = "SNS topic ARN for ElastiCache cluster notifications."
  type        = string
  default     = null
}

variable "tags" {
  description = "Tags applied to all resources."
  type        = map(string)
  default     = {}
}
