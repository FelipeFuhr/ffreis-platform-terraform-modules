output "lambda_arn" {
  description = "ARN of the email forwarder Lambda function."
  value       = aws_lambda_function.forwarder.arn
}

output "lambda_function_name" {
  description = "Name of the email forwarder Lambda function."
  value       = aws_lambda_function.forwarder.function_name
}

output "email_bucket_id" {
  description = "S3 bucket name where raw inbound emails are stored."
  value       = aws_s3_bucket.emails.id
}

output "email_bucket_arn" {
  description = "S3 bucket ARN where raw inbound emails are stored."
  value       = aws_s3_bucket.emails.arn
}

output "rule_set_name" {
  description = "SES receipt rule set name (set as the active rule set)."
  value       = aws_ses_receipt_rule_set.this.rule_set_name
}
