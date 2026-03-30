output "tags" {
  description = "Complete tag map to pass as `tags` to every other module."
  value       = local.tags
}

output "workspace" {
  description = "Workspace tag value (useful for name prefixes)."
  value       = var.workspace
}

output "service" {
  description = "Service tag value."
  value       = var.service
}
