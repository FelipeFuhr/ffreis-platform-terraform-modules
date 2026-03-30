output "db_instance_id" {
  description = "RDS instance identifier."
  value       = aws_db_instance.this.id
}

output "db_instance_arn" {
  description = "RDS instance ARN."
  value       = aws_db_instance.this.arn
}

output "db_instance_endpoint" {
  description = "Connection endpoint (host:port)."
  value       = aws_db_instance.this.endpoint
}

output "db_instance_address" {
  description = "Hostname of the RDS instance."
  value       = aws_db_instance.this.address
}

output "db_instance_port" {
  description = "Database port."
  value       = aws_db_instance.this.port
}

output "db_name" {
  description = "Name of the initial database."
  value       = aws_db_instance.this.db_name
}

output "master_username" {
  description = "Master DB username."
  value       = aws_db_instance.this.username
  sensitive   = true
}

output "master_user_secret_arn" {
  description = "ARN of the Secrets Manager secret containing the master password (when manage_master_user_password = true)."
  value       = var.manage_master_user_password ? try(aws_db_instance.this.master_user_secret[0].secret_arn, "") : ""
}
