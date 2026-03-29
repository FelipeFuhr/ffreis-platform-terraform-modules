variable "vpc_id" {
  description = "VPC ID in which to create the endpoints."
  type        = string
}

variable "region" {
  description = "AWS region (used to construct service names)."
  type        = string
}

# ---------------------------------------------------------------------------
# Gateway endpoints (S3, DynamoDB) — free, route-table based
# ---------------------------------------------------------------------------
variable "gateway_endpoints" {
  description = <<-EOT
    Map of logical name → Gateway endpoint service name suffix.
    Common values: 's3', 'dynamodb'.
    Route table IDs that should reach the endpoint are provided in
    gateway_route_table_ids.
  EOT
  type    = map(string)
  default = {}

  # Example:
  # gateway_endpoints = {
  #   s3       = "s3"
  #   dynamodb = "dynamodb"
  # }
}

variable "gateway_route_table_ids" {
  description = "Route table IDs that will use Gateway endpoints. Typically all private + database route tables."
  type        = list(string)
  default     = []
}

# ---------------------------------------------------------------------------
# Interface endpoints (most AWS services) — ENI-based, billed per AZ-hour
# ---------------------------------------------------------------------------
variable "interface_endpoints" {
  description = <<-EOT
    Map of logical name → Interface endpoint service name suffix.
    Common values: 'ssm', 'ssmmessages', 'ec2messages', 'ecr.api', 'ecr.dkr',
    'sts', 'secretsmanager', 'kms', 'logs', 'monitoring', 'sqs', 'sns',
    'lambda', 'execute-api', 'states', 'elasticloadbalancing'.
  EOT
  type    = map(string)
  default = {}
}

variable "interface_subnet_ids" {
  description = "Subnet IDs where Interface endpoint ENIs are placed. Use private subnets."
  type        = list(string)
  default     = []
}

variable "interface_security_group_ids" {
  description = "Security group IDs attached to Interface endpoint ENIs."
  type        = list(string)
  default     = []
}

variable "private_dns_enabled" {
  description = "Enable private DNS for Interface endpoints (resolves public hostnames to endpoint IPs)."
  type        = bool
  default     = true
}

variable "endpoint_policy" {
  description = "JSON endpoint policy applied to all endpoints. null = full access."
  type        = string
  default     = null
}

variable "tags" {
  description = "Tags applied to all resources."
  type        = map(string)
  default     = {}
}
