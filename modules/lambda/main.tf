locals {
  create_role  = var.execution_role_arn == null
  role_arn     = local.create_role ? aws_iam_role.lambda[0].arn : var.execution_role_arn
  package_type = var.image_uri != null ? local.lambda_package_type_image : local.lambda_package_type_zip

  lambda_package_type_image = "Image"
  lambda_package_type_zip   = "Zip"

  iam_effect_allow           = "Allow"
  iam_action_sts_assume_role = "sts:AssumeRole"
  iam_principal_type_service = "Service"

  # VPC requires AWSLambdaVPCAccessExecutionRole if we manage the role.
  vpc_policy = (local.create_role && length(var.vpc_subnet_ids) > 0) ? [
    "arn:aws:iam::aws:policy/service-role/AWSLambdaVPCAccessExecutionRole"
  ] : []

  managed_policies = concat(
    local.create_role ? ["arn:aws:iam::aws:policy/service-role/AWSLambdaBasicExecutionRole"] : [],
    local.vpc_policy,
    var.managed_policy_arns,
  )
}

# ---------------------------------------------------------------------------
# Execution role
# ---------------------------------------------------------------------------
data "aws_iam_policy_document" "lambda_assume" {
  count = local.create_role ? 1 : 0

  statement {
    effect  = local.iam_effect_allow
    actions = [local.iam_action_sts_assume_role]
    principals {
      type        = local.iam_principal_type_service
      identifiers = ["lambda.amazonaws.com"]
    }
  }
}

resource "aws_iam_role" "lambda" {
  count = local.create_role ? 1 : 0

  name               = "${var.function_name}-exec"
  assume_role_policy = data.aws_iam_policy_document.lambda_assume[0].json
  tags               = var.tags
}

resource "aws_iam_role_policy_attachment" "lambda" {
  for_each = local.create_role ? toset(local.managed_policies) : toset([])

  role       = aws_iam_role.lambda[0].name
  policy_arn = each.value
}

resource "aws_iam_role_policy" "lambda_inline" {
  for_each = local.create_role ? var.inline_policies : {}

  name   = each.key
  role   = aws_iam_role.lambda[0].id
  policy = each.value
}

# ---------------------------------------------------------------------------
# CloudWatch log group (pre-create so we control retention and encryption)
# ---------------------------------------------------------------------------
resource "aws_cloudwatch_log_group" "lambda" {
  name              = "/aws/lambda/${var.function_name}"
  retention_in_days = var.log_retention_days
  kms_key_id        = var.log_kms_key_arn

  tags = var.tags
}

# ---------------------------------------------------------------------------
# Lambda function
# ---------------------------------------------------------------------------
resource "aws_lambda_function" "this" {
  #checkov:skip=CKV_AWS_272:Code signing requires a pre-existing Code Signing Config; enforce in the calling stack where the profile ARN is known.
  function_name = var.function_name
  description   = var.description
  role          = local.role_arn
  package_type  = local.package_type
  architectures = var.architectures

  # Zip deployment
  filename         = local.package_type == local.lambda_package_type_zip ? var.filename : null
  source_code_hash = local.package_type == local.lambda_package_type_zip ? var.source_code_hash : null
  handler          = local.package_type == local.lambda_package_type_zip ? var.handler : null
  runtime          = local.package_type == local.lambda_package_type_zip ? var.runtime : null

  # Container image deployment
  image_uri = local.package_type == local.lambda_package_type_image ? var.image_uri : null

  memory_size                    = var.memory_size
  timeout                        = var.timeout
  layers                         = var.layers
  reserved_concurrent_executions = var.reserved_concurrent_executions
  kms_key_arn                    = var.kms_key_arn

  dynamic "environment" {
    for_each = length(var.environment_variables) > 0 ? tolist(["enabled"]) : tolist([])
    content {
      variables = var.environment_variables
    }
  }

  dynamic "vpc_config" {
    for_each = length(var.vpc_subnet_ids) > 0 ? tolist(["enabled"]) : tolist([])
    content {
      subnet_ids         = var.vpc_subnet_ids
      security_group_ids = var.vpc_security_group_ids
    }
  }

  dynamic "dead_letter_config" {
    for_each = var.dead_letter_target_arn != null ? toset(["enabled"]) : toset([])
    content {
      target_arn = var.dead_letter_target_arn
    }
  }

  tracing_config {
    mode = "Active"
  }

  # Ensure the log group exists before the function (avoid race on first deploy).
  depends_on = [aws_cloudwatch_log_group.lambda]

  tags = var.tags
}

# ---------------------------------------------------------------------------
# Event source mappings
# ---------------------------------------------------------------------------
resource "aws_lambda_event_source_mapping" "this" {
  for_each = var.event_source_mappings

  event_source_arn                   = each.value.event_source_arn
  function_name                      = aws_lambda_function.this.arn
  batch_size                         = each.value.batch_size
  maximum_batching_window_in_seconds = each.value.maximum_batching_window_in_seconds
  starting_position                  = each.value.starting_position
  enabled                            = each.value.enabled
  bisect_batch_on_function_error     = each.value.bisect_batch_on_function_error
  maximum_retry_attempts             = each.value.maximum_retry_attempts
  parallelization_factor             = each.value.parallelization_factor
  tumbling_window_in_seconds         = each.value.tumbling_window_in_seconds
  function_response_types            = each.value.function_response_types

  dynamic "filter_criteria" {
    for_each = length(each.value.filter_criteria) > 0 ? toset(["enabled"]) : toset([])
    content {
      dynamic "filter" {
        for_each = { for idx, f in each.value.filter_criteria : tostring(idx) => f }
        content {
          pattern = filter.value.pattern
        }
      }
    }
  }
}
