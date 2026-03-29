output "arn" {
  description = "State machine ARN."
  value       = aws_sfn_state_machine.this.arn
}

output "name" {
  description = "State machine name."
  value       = aws_sfn_state_machine.this.name
}

output "role_arn" {
  description = "IAM role ARN used by the state machine."
  value       = local.create_role ? aws_iam_role.sfn[0].arn : var.role_arn
}

output "log_group_arn" {
  description = "CloudWatch log group ARN for execution logs."
  value       = var.log_level != "OFF" ? aws_cloudwatch_log_group.sfn[0].arn : ""
}
