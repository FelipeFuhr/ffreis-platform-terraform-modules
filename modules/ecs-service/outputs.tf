output "service_id" {
  description = "ECS service ID."
  value       = aws_ecs_service.this.id
}

output "service_name" {
  description = "ECS service name."
  value       = aws_ecs_service.this.name
}

output "task_definition_arn" {
  description = "Active task definition ARN."
  value       = aws_ecs_task_definition.this.arn
}

output "task_definition_family" {
  description = "Task definition family name."
  value       = aws_ecs_task_definition.this.family
}

output "task_role_arn" {
  description = "Task IAM role ARN."
  value       = local.create_task_role ? aws_iam_role.task[0].arn : var.task_role_arn
}

output "task_role_name" {
  description = "Task IAM role name."
  value       = local.create_task_role ? aws_iam_role.task[0].name : ""
}

output "execution_role_arn" {
  description = "Task execution IAM role ARN."
  value       = local.create_execution_role ? aws_iam_role.execution[0].arn : var.task_execution_role_arn
}
