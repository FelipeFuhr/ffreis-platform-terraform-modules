# ---------------------------------------------------------------------------
# Gateway endpoints (S3, DynamoDB)
# Free of charge — traffic never leaves the AWS backbone.
# ---------------------------------------------------------------------------
resource "aws_vpc_endpoint" "gateway" {
  for_each = var.gateway_endpoints

  vpc_id            = var.vpc_id
  service_name      = "com.amazonaws.${var.region}.${each.value}"
  vpc_endpoint_type = "Gateway"
  route_table_ids   = var.gateway_route_table_ids
  policy            = var.endpoint_policy

  tags = merge(var.tags, { Name = "${each.key}-gateway-endpoint" })
}

# ---------------------------------------------------------------------------
# Interface endpoints (ENI-based — billed per AZ-hour + data processed)
# Enable private_dns so existing SDK calls resolve to the endpoint automatically.
# ---------------------------------------------------------------------------
resource "aws_vpc_endpoint" "interface" {
  for_each = var.interface_endpoints

  vpc_id              = var.vpc_id
  service_name        = "com.amazonaws.${var.region}.${each.value}"
  vpc_endpoint_type   = "Interface"
  subnet_ids          = var.interface_subnet_ids
  security_group_ids  = var.interface_security_group_ids
  private_dns_enabled = var.private_dns_enabled
  policy              = var.endpoint_policy

  tags = merge(var.tags, { Name = "${each.key}-interface-endpoint" })
}
