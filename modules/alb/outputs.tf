output "arn" {
  description = "ALB ARN."
  value       = aws_lb.this.arn
}

output "dns_name" {
  description = "ALB DNS name (point Route 53 alias records here)."
  value       = aws_lb.this.dns_name
}

output "zone_id" {
  description = "ALB hosted zone ID (use in Route 53 alias records)."
  value       = aws_lb.this.zone_id
}

output "https_listener_arn" {
  description = "HTTPS listener ARN (add extra listener rules here)."
  value       = aws_lb_listener.https[0].arn
}

output "http_listener_arn" {
  description = "HTTP listener ARN."
  value       = length(aws_lb_listener.http) > 0 ? aws_lb_listener.http[0].arn : ""
}

output "target_group_arns" {
  description = "Map of target group name → ARN."
  value       = { for k, v in aws_lb_target_group.this : k => v.arn }
}

output "security_group_ids" {
  description = "Security group IDs associated with the ALB."
  value       = var.security_group_ids
}
