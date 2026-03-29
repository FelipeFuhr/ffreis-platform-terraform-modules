variable "identifier" {
  description = "RDS instance identifier (must be unique within the account/region)."
  type        = string
}

variable "engine" {
  description = "Database engine: 'postgres' or 'mysql'."
  type        = string
  default     = "postgres"

  validation {
    condition     = contains(["postgres", "mysql"], var.engine)
    error_message = "engine must be 'postgres' or 'mysql'."
  }
}

variable "engine_version" {
  description = "Engine version (e.g. '16.3' for PostgreSQL, '8.0' for MySQL)."
  type        = string
}

variable "instance_class" {
  description = "RDS instance class (e.g. 'db.t4g.micro', 'db.r7g.large')."
  type        = string
}

variable "allocated_storage" {
  description = "Initial allocated storage in GiB."
  type        = number
  default     = 20
}

variable "max_allocated_storage" {
  description = "Maximum autoscaling storage cap in GiB. 0 = disable autoscaling."
  type        = number
  default     = 100
}

variable "storage_type" {
  description = "Storage type: 'gp3' (recommended), 'gp2', or 'io1'."
  type        = string
  default     = "gp3"
}

variable "storage_encrypted" {
  description = "Encrypt the DB storage. Always true for production."
  type        = bool
  default     = true
}

variable "kms_key_id" {
  description = "KMS key ARN for storage encryption. null = AWS-managed RDS key."
  type        = string
  default     = null
}

variable "db_name" {
  description = "Name of the initial database to create."
  type        = string
  default     = null
}

variable "username" {
  description = "Master DB username."
  type        = string
}

variable "password" {
  description = "Master DB password. Use aws_db_password_policy or Secrets Manager for production."
  type        = string
  sensitive   = true
  default     = null
}

variable "manage_master_user_password" {
  description = "Let RDS manage the master password in Secrets Manager. Recommended over plain password."
  type        = bool
  default     = true
}

variable "master_user_secret_kms_key_id" {
  description = "KMS key for the Secrets Manager-managed password."
  type        = string
  default     = null
}

variable "port" {
  description = "DB port. Defaults to engine default (5432 for postgres, 3306 for mysql)."
  type        = number
  default     = null
}

variable "multi_az" {
  description = "Enable Multi-AZ deployment for high availability."
  type        = bool
  default     = true
}

variable "db_subnet_group_name" {
  description = "Name of the DB subnet group. Must already exist."
  type        = string
}

variable "vpc_security_group_ids" {
  description = "List of VPC security group IDs."
  type        = list(string)
}

variable "publicly_accessible" {
  description = "Make the DB publicly accessible. Never enable for production."
  type        = bool
  default     = false
}

variable "deletion_protection" {
  description = "Enable deletion protection. Highly recommended for production."
  type        = bool
  default     = true
}

variable "skip_final_snapshot" {
  description = "Skip final snapshot on deletion. Set false for production."
  type        = bool
  default     = false
}

variable "final_snapshot_identifier" {
  description = "Identifier for the final snapshot. Ignored when skip_final_snapshot = true."
  type        = string
  default     = null
}

variable "backup_retention_period" {
  description = "Automated backup retention in days (0–35). 0 disables backups."
  type        = number
  default     = 7
}

variable "backup_window" {
  description = "Preferred UTC backup window (e.g. '03:00-04:00')."
  type        = string
  default     = "03:00-04:00"
}

variable "maintenance_window" {
  description = "Preferred UTC maintenance window (e.g. 'Mon:04:00-Mon:05:00')."
  type        = string
  default     = "Mon:04:00-Mon:05:00"
}

variable "auto_minor_version_upgrade" {
  description = "Automatically apply minor engine upgrades during the maintenance window."
  type        = bool
  default     = true
}

variable "apply_immediately" {
  description = "Apply changes immediately (may cause downtime). False = next maintenance window."
  type        = bool
  default     = false
}

variable "parameter_group_name" {
  description = "DB parameter group name. null = engine default."
  type        = string
  default     = null
}

variable "option_group_name" {
  description = "DB option group name (MySQL only). null = engine default."
  type        = string
  default     = null
}

variable "enabled_cloudwatch_logs_exports" {
  description = "Log types to export to CloudWatch (e.g. ['postgresql', 'upgrade'] or ['error', 'slowquery'])."
  type        = list(string)
  default     = ["postgresql", "upgrade"]
}

variable "iam_database_authentication_enabled" {
  description = "Enable IAM database authentication."
  type        = bool
  default     = true
}

variable "monitoring_interval" {
  description = "Enhanced monitoring interval in seconds (0, 1, 5, 10, 15, 30, 60). 0 = disabled."
  type        = number
  default     = 60
}

variable "performance_insights_enabled" {
  description = "Enable Performance Insights."
  type        = bool
  default     = true
}

variable "performance_insights_kms_key_id" {
  description = "KMS key for Performance Insights data. null = AWS-managed key."
  type        = string
  default     = null
}

variable "performance_insights_retention_period" {
  description = "Performance Insights data retention in days (7 or 731)."
  type        = number
  default     = 7
}

variable "ca_cert_identifier" {
  description = "CA certificate identifier for SSL/TLS. Recommended: 'rds-ca-rsa2048-g1'."
  type        = string
  default     = "rds-ca-rsa2048-g1"
}

variable "tags" {
  description = "Tags applied to all resources."
  type        = map(string)
  default     = {}
}
