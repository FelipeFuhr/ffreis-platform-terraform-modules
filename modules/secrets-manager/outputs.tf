output "secret_arn" {
  description = "Secret ARN."
  value       = aws_secretsmanager_secret.this.arn
}

output "secret_id" {
  description = "Secret ID (same as ARN for Secrets Manager)."
  value       = aws_secretsmanager_secret.this.id
}

output "secret_name" {
  description = "Secret name."
  value       = aws_secretsmanager_secret.this.name
}

output "version_id" {
  description = "Secret version ID of the current secret value."
  value       = length(aws_secretsmanager_secret_version.this) > 0 ? aws_secretsmanager_secret_version.this[0].version_id : ""
}
