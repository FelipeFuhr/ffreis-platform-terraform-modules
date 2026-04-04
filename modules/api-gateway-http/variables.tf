variable "name" {
  description = "HTTP API name."
  type        = string
}

variable "description" {
  description = "Human-readable description."
  type        = string
  default     = ""
}

variable "protocol_type" {
  description = "'HTTP' or 'WEBSOCKET'."
  type        = string
  default     = "HTTP"
}

variable "cors_configuration" {
  description = "CORS settings. null = no CORS configuration."
  type = object({
    allow_origins     = optional(list(string), ["*"])
    allow_methods     = optional(list(string), ["GET", "POST", "PUT", "PATCH", "DELETE", "OPTIONS", "HEAD"])
    allow_headers     = optional(list(string), ["Content-Type", "Authorization", "X-Amz-Date", "X-Api-Key"])
    expose_headers    = optional(list(string), [])
    max_age           = optional(number, 300)
    allow_credentials = optional(bool, false)
  })
  default = null
}

variable "jwt_authorizer" {
  description = "JWT authorizer (e.g. Cognito). null = no authorizer."
  type = object({
    name             = string
    issuer           = string       # e.g. Cognito user pool endpoint
    audience         = list(string) # e.g. Cognito app client IDs
    identity_sources = optional(list(string), ["$request.header.Authorization"])
  })
  default = null
}

variable "routes" {
  description = <<-EOT
    Map of 'METHOD /path' → integration config.
    integration_uri: Lambda invoke ARN or HTTP endpoint.
    integration_type: 'AWS_PROXY' (Lambda) or 'HTTP_PROXY'.
    authorizer: 'jwt' to require the JWT authorizer; null = NONE (public route).
    authorization_scopes: OAuth2 scopes required.
  EOT
  type = map(object({
    integration_uri        = string
    integration_type       = optional(string, "AWS_PROXY")
    payload_format_version = optional(string, "2.0")
    timeout_milliseconds   = optional(number, 29000)
    authorizer             = optional(string, null)
    authorization_scopes   = optional(list(string), [])
  }))
  default = {}
}

variable "stage_name" {
  description = "Deployment stage name. '$default' = auto-deploy."
  type        = string
  default     = "$default"
}

variable "auto_deploy" {
  description = "Auto-deploy on change."
  type        = bool
  default     = true
}

variable "access_log_arn" {
  description = "CloudWatch log group ARN for access logs. null = create a log group in this module."
  type        = string
  default     = null
}

variable "access_log_format" {
  description = "Access log format for the stage."
  type        = string
  default     = "{\"httpMethod\":\"$context.httpMethod\",\"integrationErrorMessage\":\"$context.integrationErrorMessage\",\"ip\":\"$context.identity.sourceIp\",\"path\":\"$context.path\",\"requestId\":\"$context.requestId\",\"requestTime\":\"$context.requestTime\",\"responseLength\":\"$context.responseLength\",\"routeKey\":\"$context.routeKey\",\"status\":\"$context.status\",\"userAgent\":\"$context.identity.userAgent\"}"
}

variable "access_log_retention_days" {
  description = "Retention in days for the access log group created by this module (when access_log_arn is null)."
  type        = number
  default     = 30
}

variable "access_log_kms_key_arn" {
  description = "KMS key ARN for encrypting the access log group created by this module (when access_log_arn is null)."
  type        = string
  default     = null
}

variable "throttle_burst_limit" {
  description = "Stage throttle burst limit. -1 = no limit."
  type        = number
  default     = 500
}

variable "throttle_rate_limit" {
  description = "Stage throttle rate limit (requests/second). -1 = no limit."
  type        = number
  default     = 1000
}

variable "tags" {
  description = "Tags applied to all resources."
  type        = map(string)
  default     = {}
}
