output "arn" {
  description = "IAM role ARN."
  value       = aws_iam_role.this.arn
}

output "name" {
  description = "IAM role name."
  value       = aws_iam_role.this.name
}

output "id" {
  description = "IAM role unique ID."
  value       = aws_iam_role.this.unique_id
}
