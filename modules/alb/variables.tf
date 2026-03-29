variable "name" {
  description = "ALB name (max 32 chars)."
  type        = string
}

variable "internal" {
  description = "Create an internal (private) ALB. false = internet-facing."
  type        = bool
  default     = false
}

variable "vpc_id" {
  description = "VPC ID."
  type        = string
}

variable "subnet_ids" {
  description = "Subnet IDs for the ALB. Use public subnets for internet-facing, private for internal."
  type        = list(string)
}

variable "security_group_ids" {
  description = "Security group IDs. A security group allowing inbound 80/443 from the internet is expected."
  type        = list(string)
}

variable "certificate_arn" {
  description = "ACM certificate ARN for HTTPS listener. Required when create_https_listener = true."
  type        = string
  default     = null
}

variable "ssl_policy" {
  description = "HTTPS listener SSL policy."
  type        = string
  default     = "ELBSecurityPolicy-TLS13-1-2-2021-06"
}

variable "create_https_listener" {
  description = "Create an HTTPS (443) listener. Requires certificate_arn."
  type        = bool
  default     = true
}

variable "http_redirect_to_https" {
  description = "Create an HTTP (80) listener that redirects to HTTPS. Only effective when create_https_listener = true."
  type        = bool
  default     = true
}

variable "idle_timeout" {
  description = "Connection idle timeout in seconds."
  type        = number
  default     = 60
}

variable "enable_deletion_protection" {
  description = "Prevent the ALB from being deleted via the AWS API."
  type        = bool
  default     = true
}

variable "drop_invalid_header_fields" {
  description = "Drop HTTP headers with invalid field values. Security hardening."
  type        = bool
  default     = true
}

variable "access_logs_bucket" {
  description = "S3 bucket name for ALB access logs. Empty = disabled."
  type        = string
  default     = ""
}

variable "access_logs_prefix" {
  description = "S3 prefix for access logs."
  type        = string
  default     = ""
}

variable "waf_acl_arn" {
  description = "WAF WebACL ARN to associate with the ALB."
  type        = string
  default     = null
}

variable "target_groups" {
  description = <<-EOT
    Map of target group name → configuration. Each entry is available as an
    output so listeners and ECS services can reference target group ARNs.
  EOT
  type = map(object({
    port             = number
    protocol         = optional(string, "HTTP")
    target_type      = optional(string, "ip") # ip | instance | lambda
    deregistration_delay = optional(number, 30)
    health_check = optional(object({
      path                = optional(string, "/")
      protocol            = optional(string, "HTTP")
      matcher             = optional(string, "200-399")
      interval            = optional(number, 30)
      timeout             = optional(number, 5)
      healthy_threshold   = optional(number, 2)
      unhealthy_threshold = optional(number, 3)
    }), {})
    stickiness = optional(object({
      enabled  = bool
      duration = optional(number, 86400)
    }), null)
  }))
  default = {}
}

variable "https_listener_rules" {
  description = <<-EOT
    Map of rule name → listener rule on the HTTPS listener.
    target_group: key from var.target_groups that this rule forwards to.
    priority: rule evaluation priority (1–50000).
    conditions: list of path_pattern or host_header conditions.
  EOT
  type = map(object({
    target_group = string
    priority     = number
    conditions = list(object({
      field  = string       # "path-pattern" | "host-header"
      values = list(string)
    }))
  }))
  default = {}
}

variable "tags" {
  description = "Tags applied to all resources."
  type        = map(string)
  default     = {}
}
