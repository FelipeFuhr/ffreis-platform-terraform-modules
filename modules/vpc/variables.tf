variable "name" {
  description = "Name prefix applied to all VPC resources."
  type        = string
}

variable "cidr" {
  description = "Primary IPv4 CIDR block for the VPC (e.g. '10.0.0.0/16')."
  type        = string
}

variable "azs" {
  description = "List of Availability Zones to use. Length must match public/private subnet CIDR lists."
  type        = list(string)
}

variable "public_subnet_cidrs" {
  description = "CIDRs for public subnets — one per AZ. These subnets route to the Internet Gateway."
  type        = list(string)
  default     = []
}

variable "private_subnet_cidrs" {
  description = "CIDRs for private subnets — one per AZ. These subnets route to NAT Gateway(s)."
  type        = list(string)
  default     = []
}

variable "database_subnet_cidrs" {
  description = "CIDRs for isolated database subnets — one per AZ. No default route to internet."
  type        = list(string)
  default     = []
}

variable "enable_nat_gateway" {
  description = "Provision NAT Gateway(s) for private subnets."
  type        = bool
  default     = true
}

variable "single_nat_gateway" {
  description = "Use a single NAT Gateway shared across all AZs (cost-effective for non-prod)."
  type        = bool
  default     = false
}

variable "enable_dns_hostnames" {
  description = "Enable DNS hostnames in the VPC."
  type        = bool
  default     = true
}

variable "enable_dns_support" {
  description = "Enable DNS support in the VPC."
  type        = bool
  default     = true
}

variable "enable_flow_logs" {
  description = "Enable VPC Flow Logs to CloudWatch Logs."
  type        = bool
  default     = true
}

variable "flow_logs_retention_days" {
  description = "CloudWatch log retention for VPC Flow Logs."
  type        = number
  default     = 365
}

variable "flow_logs_kms_key_arn" {
  description = "KMS key ARN for encrypting Flow Log CloudWatch log group. null = AWS-managed."
  type        = string
  default     = null
}

variable "restrict_default_security_group" {
  description = "Restrict the default security group to no ingress/egress."
  type        = bool
  default     = true
}

variable "create_database_subnet_group" {
  description = "Create an aws_db_subnet_group from the database subnets."
  type        = bool
  default     = true
}

variable "public_subnet_tags" {
  description = "Additional tags for public subnets (e.g. kubernetes.io/role/elb = 1)."
  type        = map(string)
  default     = {}
}

variable "private_subnet_tags" {
  description = "Additional tags for private subnets (e.g. kubernetes.io/role/internal-elb = 1)."
  type        = map(string)
  default     = {}
}

variable "database_subnet_tags" {
  description = "Additional tags for database subnets."
  type        = map(string)
  default     = {}
}

variable "tags" {
  description = "Tags applied to all resources."
  type        = map(string)
  default     = {}
}
