output "id" {
  description = "ECS cluster ID."
  value       = aws_ecs_cluster.this.id
}

output "arn" {
  description = "ECS cluster ARN."
  value       = aws_ecs_cluster.this.arn
}

output "name" {
  description = "ECS cluster name."
  value       = aws_ecs_cluster.this.name
}
