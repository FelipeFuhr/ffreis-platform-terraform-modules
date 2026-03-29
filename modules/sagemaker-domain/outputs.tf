output "domain_id" {
  description = "SageMaker Studio domain ID."
  value       = aws_sagemaker_domain.this.id
}

output "domain_arn" {
  description = "SageMaker Studio domain ARN."
  value       = aws_sagemaker_domain.this.arn
}

output "home_efs_file_system_id" {
  description = "EFS file system ID backing the SageMaker home directories."
  value       = aws_sagemaker_domain.this.home_efs_file_system_id
}

output "url" {
  description = "Domain presigned URL for Studio access."
  value       = aws_sagemaker_domain.this.url
}

output "user_profile_arns" {
  description = "Map of user profile name → ARN."
  value       = { for k, v in aws_sagemaker_user_profile.this : k => v.arn }
}
