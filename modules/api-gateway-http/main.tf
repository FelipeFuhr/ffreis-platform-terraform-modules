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

resource "aws_apigatewayv2_route" "this" {
  for_each = var.routes

  api_id    = aws_apigatewayv2_api.this.id
  route_key = each.key
  target    = "integrations/${aws_apigatewayv2_integration.this[each.key].id}"

  authorization_type   = each.value.authorizer == "jwt" ? "JWT" : "NONE"
  authorizer_id        = each.value.authorizer == "jwt" && var.jwt_authorizer != null ? aws_apigatewayv2_authorizer.jwt[0].id : null
  authorization_scopes = each.value.authorizer == "jwt" ? each.value.authorization_scopes : null
}

# ---------------------------------------------------------------------------
# Stage
# ---------------------------------------------------------------------------
resource "aws_apigatewayv2_stage" "this" {
  api_id      = aws_apigatewayv2_api.this.id
  name        = var.stage_name
  auto_deploy = var.auto_deploy

  dynamic "access_log_settings" {
    for_each = var.access_log_arn != null ? [1] : []
    content {
      destination_arn = var.access_log_arn
    }
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

data "aws_region" "current" {}
data "aws_caller_identity" "current" {}

resource "aws_lambda_permission" "apigw" {
  for_each = local.lambda_routes

  statement_id  = "AllowAPIGatewayInvoke-${replace(replace(each.key, " ", "-"), "/", "-")}"
  action        = "lambda:InvokeFunction"
  function_name = each.value.integration_uri
  principal     = "apigateway.amazonaws.com"
  source_arn    = "${aws_apigatewayv2_api.this.execution_arn}/*/*"
}
