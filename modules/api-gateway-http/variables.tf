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
    authorizer: 'jwt' to require the JWT authorizer, or null for public.
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
  description = "CloudWatch log group ARN for access logs. null = disabled."
  type        = string
  default     = null
}

variable "access_log_format" {
  description = "Access log format for the stage. Only used when access_log_arn is set."
  type        = string
  default = jsonencode({
    requestId               = "$context.requestId"
    requestTime             = "$context.requestTime"
    httpMethod              = "$context.httpMethod"
    routeKey                = "$context.routeKey"
    path                    = "$context.path"
    status                  = "$context.status"
    responseLength          = "$context.responseLength"
    ip                      = "$context.identity.sourceIp"
    userAgent               = "$context.identity.userAgent"
    integrationErrorMessage = "$context.integrationErrorMessage"
  })
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
