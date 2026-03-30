output "trail_arn" {
  description = "CloudTrail trail ARN."
  value       = aws_cloudtrail.this.arn
}

output "trail_name" {
  description = "CloudTrail trail name."
  value       = aws_cloudtrail.this.name
}

output "cloudwatch_log_group_arn" {
  description = "ARN of the CloudWatch Logs log group."
  value       = aws_cloudwatch_log_group.trail.arn
}

output "cloudwatch_role_arn" {
  description = "ARN of the IAM role used to push events to CloudWatch Logs."
  value       = aws_iam_role.cloudtrail.arn
}
