output "function_arn" {
  description = "Lambda function ARN."
  value       = aws_lambda_function.this.arn
}

output "function_name" {
  description = "Lambda function name."
  value       = aws_lambda_function.this.function_name
}

output "invoke_arn" {
  description = "ARN used to invoke the function from API Gateway or other services."
  value       = aws_lambda_function.this.invoke_arn
}

output "qualified_arn" {
  description = "Qualified ARN (includes function version)."
  value       = aws_lambda_function.this.qualified_arn
}

output "execution_role_arn" {
  description = "IAM execution role ARN."
  value       = local.role_arn
}

output "execution_role_name" {
  description = "IAM execution role name (empty if an external role was provided)."
  value       = local.create_role ? aws_iam_role.lambda[0].name : ""
}

output "log_group_name" {
  description = "CloudWatch log group name for this function."
  value       = aws_cloudwatch_log_group.lambda.name
}

output "log_group_arn" {
  description = "CloudWatch log group ARN."
  value       = aws_cloudwatch_log_group.lambda.arn
}
