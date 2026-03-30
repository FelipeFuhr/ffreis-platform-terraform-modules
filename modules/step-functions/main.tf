locals {
  create_role = var.role_arn == null

  log_level_off = "OFF"

  iam_effect_allow           = "Allow"
  iam_action_sts_assume_role = "sts:AssumeRole"
  iam_principal_type_service = "Service"
  iam_resource_all           = "*"
}

# ---------------------------------------------------------------------------
# Execution role
# ---------------------------------------------------------------------------
data "aws_iam_policy_document" "sfn_assume" {
  count = local.create_role ? 1 : 0

  statement {
    effect  = local.iam_effect_allow
    actions = [local.iam_action_sts_assume_role]
    principals {
      type        = local.iam_principal_type_service
      identifiers = ["states.amazonaws.com"]
    }
  }
}

resource "aws_iam_role" "sfn" {
  count              = local.create_role ? 1 : 0
  name               = "${var.name}-sfn"
  assume_role_policy = data.aws_iam_policy_document.sfn_assume[0].json
  tags               = var.tags
}

resource "aws_iam_role_policy_attachment" "sfn" {
  for_each   = local.create_role ? toset(var.role_managed_policy_arns) : toset([])
  role       = aws_iam_role.sfn[0].name
  policy_arn = each.value
}

resource "aws_iam_role_policy" "sfn_inline" {
  for_each = local.create_role ? var.role_inline_policies : {}
  name     = each.key
  role     = aws_iam_role.sfn[0].id
  policy   = each.value
}

# CloudWatch Logs write permission for the execution role.
data "aws_iam_policy_document" "sfn_logs" {
  count = local.create_role && var.log_level != local.log_level_off ? 1 : 0

  statement {
    effect = local.iam_effect_allow
    actions = [
      "logs:CreateLogDelivery",
      "logs:GetLogDelivery",
      "logs:UpdateLogDelivery",
      "logs:DeleteLogDelivery",
      "logs:ListLogDeliveries",
      "logs:PutResourcePolicy",
      "logs:DescribeResourcePolicies",
      "logs:DescribeLogGroups",
    ]
    resources = [local.iam_resource_all]
  }
}

resource "aws_iam_role_policy" "sfn_logs" {
  count  = local.create_role && var.log_level != local.log_level_off ? 1 : 0
  name   = "write-execution-logs"
  role   = aws_iam_role.sfn[0].id
  policy = data.aws_iam_policy_document.sfn_logs[0].json
}

# ---------------------------------------------------------------------------
# CloudWatch log group for executions
# ---------------------------------------------------------------------------
resource "aws_cloudwatch_log_group" "sfn" {
  count             = var.log_level != local.log_level_off ? 1 : 0
  name              = "/aws/states/${var.name}"
  retention_in_days = var.log_retention_days
  kms_key_id        = var.log_kms_key_arn
  tags              = var.tags
}

# ---------------------------------------------------------------------------
# State machine
# ---------------------------------------------------------------------------
resource "aws_sfn_state_machine" "this" {
  name       = var.name
  type       = var.type
  definition = var.definition
  role_arn   = local.create_role ? aws_iam_role.sfn[0].arn : var.role_arn

  dynamic "tracing_configuration" {
    for_each = var.enable_xray_tracing ? [1] : []
    content {
      enabled = true
    }
  }

  dynamic "logging_configuration" {
    for_each = var.log_level != "OFF" ? [1] : []
    content {
      level                  = var.log_level
      include_execution_data = var.log_include_execution_data
      log_destination        = "${aws_cloudwatch_log_group.sfn[0].arn}:*"
    }
  }

  tags = var.tags
}
