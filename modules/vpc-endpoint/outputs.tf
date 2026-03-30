output "gateway_endpoint_ids" {
  description = "Map of logical name → Gateway endpoint ID."
  value       = { for k, v in aws_vpc_endpoint.gateway : k => v.id }
}

output "interface_endpoint_ids" {
  description = "Map of logical name → Interface endpoint ID."
  value       = { for k, v in aws_vpc_endpoint.interface : k => v.id }
}

output "interface_endpoint_dns" {
  description = "Map of logical name → list of DNS entries for each Interface endpoint."
  value       = { for k, v in aws_vpc_endpoint.interface : k => v.dns_entry }
}
