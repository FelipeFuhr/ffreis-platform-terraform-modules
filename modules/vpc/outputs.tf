output "vpc_id" {
  description = "VPC ID."
  value       = aws_vpc.this.id
}

output "vpc_arn" {
  description = "VPC ARN."
  value       = aws_vpc.this.arn
}

output "vpc_cidr" {
  description = "VPC primary CIDR block."
  value       = aws_vpc.this.cidr_block
}

output "public_subnet_ids" {
  description = "IDs of all public subnets."
  value       = aws_subnet.public[*].id
}

output "private_subnet_ids" {
  description = "IDs of all private subnets."
  value       = aws_subnet.private[*].id
}

output "database_subnet_ids" {
  description = "IDs of all database subnets."
  value       = aws_subnet.database[*].id
}

output "database_subnet_group_id" {
  description = "ID of the RDS DB subnet group (empty if not created)."
  value       = length(aws_db_subnet_group.database) > 0 ? aws_db_subnet_group.database[0].id : ""
}

output "internet_gateway_id" {
  description = "Internet Gateway ID (empty if no public subnets)."
  value       = length(aws_internet_gateway.this) > 0 ? aws_internet_gateway.this[0].id : ""
}

output "nat_gateway_ids" {
  description = "IDs of the NAT Gateways."
  value       = aws_nat_gateway.this[*].id
}

output "public_route_table_id" {
  description = "Route table ID for public subnets."
  value       = length(aws_route_table.public) > 0 ? aws_route_table.public[0].id : ""
}

output "private_route_table_ids" {
  description = "Route table IDs for private subnets (one per AZ)."
  value       = aws_route_table.private[*].id
}
