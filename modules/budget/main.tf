resource "aws_budgets_budget" "this" {
  name         = var.name
  budget_type  = var.budget_type
  time_unit    = var.time_unit
  limit_amount = tostring(var.limit_amount)
  limit_unit   = "USD"

  dynamic "cost_filter" {
    for_each = var.cost_filters
    content {
      name   = cost_filter.key
      values = cost_filter.value
    }
  }

  dynamic "notification" {
    for_each = var.alert_thresholds
    content {
      comparison_operator        = notification.value.comparison_operator
      threshold                  = notification.value.threshold_percent
      threshold_type             = notification.value.threshold_type
      notification_type          = notification.value.notification_type
      subscriber_email_addresses = var.alert_email_addresses
      subscriber_sns_topic_arns  = var.alert_sns_arns
    }
  }

  tags = var.tags
}

# ── Enforcement action (opt-in; see var.action) ───────────────────────────────
#
# Without this, every budget in the fleet emails on breach and changes nothing.
# `aws_budgets_budget_action` is the only AWS mechanism that can stop spend at
# an aggregate threshold — ffreis-genai-runtime/docs/DESIGN.md §6.3 lists it as
# the one aggregate control that "would actually enforce", and §6.6 ranks adding
# it 4th by value, with the warning this module encodes in var.action's docs:
# the blast radius is "the targeted role can no longer make that call".
#
# Default OFF (var.action == null). Every resource AND data source below is
# counted off in that case, so a notify-only caller gets no plan diff and makes
# no new API call — in particular no aws_caller_identity, which would otherwise
# break any caller whose provider sets skip_requesting_account_id (the offline
# fixture pattern this repo uses in test/fixtures/api-gateway-http-statement-id).

locals {
  action_enabled = var.action != null

  # Mirrors modules/step-functions: the caller may supply a role, otherwise the
  # module makes one scoped to just this action.
  create_action_role = local.action_enabled && try(var.action.execution_role_arn, null) == null

  action_is_iam = local.action_enabled && try(var.action.iam, null) != null
  action_is_ssm = local.action_enabled && try(var.action.ssm, null) != null

  # one() over a splat yields null when the data source is counted off, rather
  # than failing on a [0] index.
  #
  # Locals are evaluated eagerly — even the untaken branch of a conditional and
  # even when nothing consumes them — so each of these must resolve to a plain
  # null when its data source is absent, and every consumer below has to be
  # gated on the same predicate that gates the data source. Getting this wrong
  # fails the notify-only plan, which is the one case that must keep working.
  action_partition  = one(data.aws_partition.current[*].partition)
  action_account_id = one(data.aws_caller_identity.current[*].account_id)

  # Required on the ssm object, so there is no data source and no provider-region
  # fallback here. Deliberate: data.aws_region's attribute for this was renamed
  # between provider majors (name -> region, each absent on the other side of
  # the bump) and this module only needs the value when an SSM action exists, so
  # an explicit caller-supplied region is both simpler and version-proof. An
  # action that stops named instances should state where they are.
  action_region = try(var.action.ssm.region, null)

  action_role_arn = (
    local.create_action_role
    ? one(aws_iam_role.budget_action[*].arn)
    : try(var.action.execution_role_arn, null)
  )

  # Target ARNs the created role is allowed to touch — and nothing else.
  #
  # Gated on create_action_role, not just action_is_iam: partition and account
  # id come from data sources that only exist when the module builds the role.
  # A caller supplying execution_role_arn has an `iam` action but no account id,
  # and interpolating the null would fail their plan.
  action_iam_target_arns = local.create_action_role && local.action_is_iam ? concat(
    [for r in var.action.iam.roles : "arn:${local.action_partition}:iam::${local.action_account_id}:role/${r}"],
    [for g in var.action.iam.groups : "arn:${local.action_partition}:iam::${local.action_account_id}:group/${g}"],
    [for u in var.action.iam.users : "arn:${local.action_partition}:iam::${local.action_account_id}:user/${u}"],
  ) : []
}

data "aws_partition" "current" {
  count = local.create_action_role ? 1 : 0
}

data "aws_caller_identity" "current" {
  count = local.create_action_role ? 1 : 0
}

# AWS Budgets assumes this role to apply the action.
#
# No confused-deputy condition on the trust policy: AWS's documented trust for
# budget actions is the bare service principal, and adding an unverified
# aws:SourceAccount condition would make an opt-in safety control fail at
# exactly the moment it is needed. The real containment is below — the role can
# attach one specific policy to one specific list of principals, or stop one
# specific list of instances, and nothing else.
data "aws_iam_policy_document" "budget_action_assume" {
  count = local.create_action_role ? 1 : 0

  statement {
    effect  = "Allow"
    actions = ["sts:AssumeRole"]
    principals {
      type        = "Service"
      identifiers = ["budgets.amazonaws.com"]
    }
  }
}

data "aws_iam_policy_document" "budget_action" {
  count = local.create_action_role ? 1 : 0

  # Attach/detach only the configured policy, only to the configured principals.
  dynamic "statement" {
    for_each = local.action_is_iam ? [1] : []
    content {
      sid    = "AttachBudgetPolicy"
      effect = "Allow"
      actions = [
        "iam:AttachRolePolicy",
        "iam:AttachGroupPolicy",
        "iam:AttachUserPolicy",
        "iam:DetachRolePolicy",
        "iam:DetachGroupPolicy",
        "iam:DetachUserPolicy",
      ]
      resources = local.action_iam_target_arns
      condition {
        test     = "ArnEquals"
        variable = "iam:PolicyARN"
        values   = [var.action.iam.policy_arn]
      }
    }
  }

  # SSM automation documents are AWS-owned and not resource-scopable here; the
  # containment for this branch is the instance-scoped statement that follows.
  dynamic "statement" {
    for_each = local.action_is_ssm ? [1] : []
    content {
      sid       = "RunBudgetStopDocument"
      effect    = "Allow"
      actions   = ["ssm:StartAutomationExecution", "ssm:GetAutomationExecution"]
      resources = ["*"]
    }
  }

  dynamic "statement" {
    for_each = local.action_is_ssm && try(var.action.ssm.action_sub_type, "") == "STOP_EC2_INSTANCES" ? [1] : []
    content {
      sid       = "StopEc2Instances"
      effect    = "Allow"
      actions   = ["ec2:StopInstances", "ec2:DescribeInstanceStatus"]
      resources = [for i in var.action.ssm.instance_ids : "arn:${local.action_partition}:ec2:${local.action_region}:${local.action_account_id}:instance/${i}"]
    }
  }

  dynamic "statement" {
    for_each = local.action_is_ssm && try(var.action.ssm.action_sub_type, "") == "STOP_RDS_INSTANCES" ? [1] : []
    content {
      sid       = "StopRdsInstances"
      effect    = "Allow"
      actions   = ["rds:StopDBInstance", "rds:DescribeDBInstances"]
      resources = [for i in var.action.ssm.instance_ids : "arn:${local.action_partition}:rds:${local.action_region}:${local.action_account_id}:db:${i}"]
    }
  }
}

resource "aws_iam_role" "budget_action" {
  count              = local.create_action_role ? 1 : 0
  name               = "${var.name}-budget-action"
  assume_role_policy = data.aws_iam_policy_document.budget_action_assume[0].json
  tags               = var.tags
}

resource "aws_iam_role_policy" "budget_action" {
  count  = local.create_action_role ? 1 : 0
  name   = "budget-action"
  role   = aws_iam_role.budget_action[0].id
  policy = data.aws_iam_policy_document.budget_action[0].json
}

resource "aws_budgets_budget_action" "this" {
  count = local.action_enabled ? 1 : 0

  budget_name        = aws_budgets_budget.this.name
  action_type        = local.action_is_iam ? "APPLY_IAM_POLICY" : "RUN_SSM_DOCUMENTS"
  approval_model     = var.action.approval_model
  notification_type  = var.action.notification_type
  execution_role_arn = local.action_role_arn

  action_threshold {
    action_threshold_type  = var.action.threshold_type
    action_threshold_value = var.action.threshold_percent
  }

  definition {
    dynamic "iam_action_definition" {
      for_each = local.action_is_iam ? [1] : []
      content {
        policy_arn = var.action.iam.policy_arn
        roles      = length(var.action.iam.roles) > 0 ? var.action.iam.roles : null
        groups     = length(var.action.iam.groups) > 0 ? var.action.iam.groups : null
        users      = length(var.action.iam.users) > 0 ? var.action.iam.users : null
      }
    }

    dynamic "ssm_action_definition" {
      for_each = local.action_is_ssm ? [1] : []
      content {
        action_sub_type = var.action.ssm.action_sub_type
        instance_ids    = var.action.ssm.instance_ids
        region          = local.action_region
      }
    }
  }

  dynamic "subscriber" {
    for_each = toset(var.action.subscriber_email_addresses)
    content {
      address           = subscriber.value
      subscription_type = "EMAIL"
    }
  }

  dynamic "subscriber" {
    for_each = toset(var.action.subscriber_sns_topic_arns)
    content {
      address           = subscriber.value
      subscription_type = "SNS"
    }
  }

  # The role must carry its policy before Budgets is told to use it.
  depends_on = [aws_iam_role_policy.budget_action]
}
