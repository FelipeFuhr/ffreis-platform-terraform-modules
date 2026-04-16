resource "aws_apigatewayv2_api" "this" {
  name          = var.name
  description   = var.description
  protocol_type = var.protocol_type

  dynamic "cors_configuration" {
    for_each = var.cors_configuration != null ? [var.cors_configuration] : []
    content {
      allow_origins     = cors_configuration.value.allow_origins
      allow_methods     = cors_configuration.value.allow_methods
      allow_headers     = cors_configuration.value.allow_headers
      expose_headers    = cors_configuration.value.expose_headers
      max_age           = cors_configuration.value.max_age
      allow_credentials = cors_configuration.value.allow_credentials
    }
  }

  tags = var.tags
}

# ---------------------------------------------------------------------------
# JWT authorizer
# ---------------------------------------------------------------------------
resource "aws_apigatewayv2_authorizer" "jwt" {
  count = var.jwt_authorizer != null ? 1 : 0

  api_id           = aws_apigatewayv2_api.this.id
  authorizer_type  = "JWT"
  name             = var.jwt_authorizer.name
  identity_sources = var.jwt_authorizer.identity_sources

  jwt_configuration {
    issuer   = var.jwt_authorizer.issuer
    audience = var.jwt_authorizer.audience
  }
}

# ---------------------------------------------------------------------------
# Integrations + routes
# ---------------------------------------------------------------------------
resource "aws_apigatewayv2_integration" "this" {
  for_each = var.routes

  api_id                 = aws_apigatewayv2_api.this.id
  integration_type       = each.value.integration_type
  integration_uri        = each.value.integration_uri
  payload_format_version = each.value.payload_format_version
  timeout_milliseconds   = each.value.timeout_milliseconds
}

#checkov:skip=CKV_AWS_309:This module supports public routes when authorizer is explicitly set to "none"; all other routes default to AWS_IAM.
resource "aws_apigatewayv2_route" "this" {
  for_each = var.routes

  api_id    = aws_apigatewayv2_api.this.id
  route_key = each.key
  target    = "integrations/${aws_apigatewayv2_integration.this[each.key].id}"

  authorization_type   = each.value.authorizer == "jwt" ? "JWT" : (each.value.authorizer == "none" ? "NONE" : "AWS_IAM")
  authorizer_id        = each.value.authorizer == "jwt" && var.jwt_authorizer != null ? aws_apigatewayv2_authorizer.jwt[0].id : null
  authorization_scopes = each.value.authorizer == "jwt" ? each.value.authorization_scopes : null
}

# ---------------------------------------------------------------------------
# Access logs (CloudWatch Logs)
# Trivy AWS-0001: enforce access logging on API Gateway stages.
# If the caller doesn't supply a destination log group ARN, create one.
# ---------------------------------------------------------------------------
resource "aws_cloudwatch_log_group" "access" {
  count = var.access_log_arn == null ? 1 : 0

  # CloudWatch log group names don't allow $ character, so replace it
  name              = "/aws/apigateway/${var.name}/${replace(var.stage_name, "$", "")}"
  retention_in_days = var.access_log_retention_days
  kms_key_id        = var.access_log_kms_key_arn

  tags = var.tags
}

locals {
  access_log_destination_arn = var.access_log_arn != null ? var.access_log_arn : aws_cloudwatch_log_group.access[0].arn
}

# ---------------------------------------------------------------------------
# Stage
# ---------------------------------------------------------------------------
resource "aws_apigatewayv2_stage" "this" {
  api_id      = aws_apigatewayv2_api.this.id
  name        = var.stage_name
  auto_deploy = var.auto_deploy

  access_log_settings {
    destination_arn = local.access_log_destination_arn
    format          = var.access_log_format
  }

  default_route_settings {
    throttling_burst_limit = var.throttle_burst_limit > 0 ? var.throttle_burst_limit : null
    throttling_rate_limit  = var.throttle_rate_limit > 0 ? var.throttle_rate_limit : null
  }

  tags = var.tags
}

# ---------------------------------------------------------------------------
# Lambda permissions — grant API Gateway the right to invoke each Lambda route
# ---------------------------------------------------------------------------
locals {
  lambda_routes = {
    for k, v in var.routes : k => v
    if v.integration_type == "AWS_PROXY"
  }
}


resource "aws_lambda_permission" "apigw" {
  for_each = local.lambda_routes

  statement_id  = "AllowAPIGatewayInvoke-${replace(replace(each.key, " ", "-"), "/", "-")}"
  action        = "lambda:InvokeFunction"
  # Extract Lambda ARN from integration_uri format:
  # arn:aws:apigateway:region:lambda:path/2015-03-31/functions/LAMBDA_ARN/invocations
  function_name = replace(
    replace(each.value.integration_uri, "/^.*\\/functions\\//", ""),
    "/\\/invocations$/",
    ""
  )
  principal  = "apigateway.amazonaws.com"
  source_arn = "${aws_apigatewayv2_api.this.execution_arn}/*/*"
}
