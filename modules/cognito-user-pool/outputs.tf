output "id" {
  description = "User pool ID."
  value       = aws_cognito_user_pool.this.id
}

output "arn" {
  description = "User pool ARN."
  value       = aws_cognito_user_pool.this.arn
}

output "endpoint" {
  description = "User pool endpoint (used as JWT issuer URL)."
  value       = aws_cognito_user_pool.this.endpoint
}

output "client_ids" {
  description = "Map of app client name → client ID."
  value       = { for k, v in aws_cognito_user_pool_client.this : k => v.id }
}

output "client_secrets" {
  description = "Map of app client name → client secret (sensitive). Only set when generate_secret = true."
  value       = { for k, v in aws_cognito_user_pool_client.this : k => v.client_secret }
  sensitive   = true
}

output "domain" {
  description = "Cognito hosted UI domain prefix."
  value       = length(aws_cognito_user_pool_domain.this) > 0 ? aws_cognito_user_pool_domain.this[0].domain : ""
}
