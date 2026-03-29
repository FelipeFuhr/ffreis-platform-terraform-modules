output "api_id" {
  description = "HTTP API ID."
  value       = aws_apigatewayv2_api.this.id
}

output "api_endpoint" {
  description = "API invocation endpoint URL."
  value       = aws_apigatewayv2_stage.this.invoke_url
}

output "execution_arn" {
  description = "API Gateway execution ARN (use in Lambda permissions)."
  value       = aws_apigatewayv2_api.this.execution_arn
}

output "authorizer_id" {
  description = "JWT authorizer ID (empty if no authorizer configured)."
  value       = var.jwt_authorizer != null ? aws_apigatewayv2_authorizer.jwt[0].id : ""
}
