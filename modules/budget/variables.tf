variable "name" {
  description = "Budget name."
  type        = string
}

variable "limit_amount" {
  description = "Maximum spend in USD before alerts fire."
  type        = number
}

variable "time_unit" {
  description = "Budget reset period: 'MONTHLY', 'QUARTERLY', or 'ANNUALLY'."
  type        = string
  default     = "MONTHLY"

  validation {
    condition     = contains(["MONTHLY", "QUARTERLY", "ANNUALLY"], var.time_unit)
    error_message = "time_unit must be MONTHLY, QUARTERLY, or ANNUALLY."
  }
}

variable "budget_type" {
  description = "'COST' (default) or 'USAGE'."
  type        = string
  default     = "COST"

  validation {
    condition     = contains(["COST", "USAGE"], var.budget_type)
    error_message = "budget_type must be 'COST' or 'USAGE'."
  }
}

variable "alert_thresholds" {
  description = <<-EOT
    List of alert thresholds. Each entry fires an SNS notification when the
    threshold is breached.
    threshold_percent: percentage of the budget limit (e.g. 80 = 80%).
    comparison_operator: 'GREATER_THAN' or 'EQUAL_TO'.
    threshold_type: 'PERCENTAGE' or 'ABSOLUTE_VALUE'.
    notification_type: 'ACTUAL' (real spend) or 'FORECASTED' (projected spend).
  EOT
  type = list(object({
    threshold_percent   = number
    comparison_operator = optional(string, "GREATER_THAN")
    threshold_type      = optional(string, "PERCENTAGE")
    notification_type   = optional(string, "ACTUAL")
  }))
  default = [
    { threshold_percent = 50, notification_type = "ACTUAL" },
    { threshold_percent = 80, notification_type = "ACTUAL" },
    { threshold_percent = 100, notification_type = "ACTUAL" },
    { threshold_percent = 100, notification_type = "FORECASTED" },
  ]
}

variable "alert_email_addresses" {
  description = "Email addresses to notify when a threshold is breached."
  type        = list(string)
  default     = []
}

variable "alert_sns_arns" {
  description = "SNS topic ARNs to notify when a threshold is breached."
  type        = list(string)
  default     = []
}

variable "cost_filters" {
  description = "Map of cost filter name → list of values (e.g. { Service = ['Amazon EC2'] })."
  type        = map(list(string))
  default     = {}
}

variable "tags" {
  description = "Tags applied to the budget."
  type        = map(string)
  default     = {}
}

# ── Enforcement action ───────────────────────────────────────────────────────

variable "action" {
  description = <<-EOT
    OPTIONAL enforcement action. Default null = OFF, i.e. notify-only, which is
    every existing caller's behaviour and stays unchanged.

    The `notification` blocks above only ever send mail. An action is the one
    AWS mechanism that can actually STOP spend at a threshold, and the only
    control in the fleet that still works when a spend bug outruns a
    per-request guard (ffreis-genai-runtime/docs/DESIGN.md §6.3, §6.6 item 4).

    Set exactly one of `iam` or `ssm`:

      iam — attach a policy to principals when the threshold trips. The usual
        shape is an explicit-deny policy on the role that spends, e.g. Deny
        bedrock:InvokeModel on a Lambda execution role. An explicit Deny beats
        any Allow, so this is a hard stop no application code can bypass.

      ssm — stop EC2 or RDS instances by id, in a region you name.

    BLAST RADIUS. An IAM action means "this principal can no longer make that
    call" until someone detaches the policy. That is a deliberate outage. Put it
    at 100% of a deliberately generous limit and let the per-request guard
    handle the normal case; do not use it as a routine throttle.

    REHEARSING IT. `approval_model = "MANUAL"` makes the action wait for a human
    in the Budgets console instead of firing. Use it to confirm the threshold
    and targets are right before switching to AUTOMATIC — but note that while it
    is MANUAL this budget still cannot stop anything on its own.

    REVERSAL IS MANUAL. AWS applies the action; it never un-applies it. Recovery
    is detaching the policy (or restarting the instances) by hand, so whoever
    owns the budget needs to know that and be on the subscriber list.
  EOT

  type = object({
    # When to act. Defaults to 100% of actual spend — the generous-limit posture
    # described above.
    threshold_percent = optional(number, 100)
    threshold_type    = optional(string, "PERCENTAGE")
    notification_type = optional(string, "ACTUAL")

    # AUTOMATIC acts on its own; MANUAL waits for console approval. Defaults to
    # AUTOMATIC because passing this object at all is opting in to enforcement —
    # a MANUAL default would behave exactly like the notify-only module it
    # replaces, which is the failure mode this variable exists to fix.
    approval_model = optional(string, "AUTOMATIC")

    iam = optional(object({
      policy_arn = string
      roles      = optional(list(string), [])
      groups     = optional(list(string), [])
      users      = optional(list(string), [])
    }))

    ssm = optional(object({
      action_sub_type = string
      instance_ids    = list(string)
      # Required, not inherited from the provider: see the note on
      # local.action_region in main.tf.
      region = string
    }))

    # Who is told the action fired. At least one is required by AWS — and by
    # the reversal-is-manual note above.
    subscriber_email_addresses = optional(list(string), [])
    subscriber_sns_topic_arns  = optional(list(string), [])

    # Role AWS Budgets assumes to apply the action. Leave null and the module
    # creates one scoped to exactly the policy and targets configured here.
    execution_role_arn = optional(string)
  })

  default = null

  validation {
    condition = (
      var.action == null ||
      (try(var.action.iam, null) != null) != (try(var.action.ssm, null) != null)
    )
    error_message = "action must set exactly one of `iam` or `ssm`."
  }

  validation {
    condition = (
      var.action == null ||
      length(var.action.subscriber_email_addresses) + length(var.action.subscriber_sns_topic_arns) > 0
    )
    error_message = "action needs at least one subscriber: the action is irreversible without a human, so someone must be told it fired."
  }

  validation {
    condition     = var.action == null || contains(["PERCENTAGE", "ABSOLUTE_VALUE"], var.action.threshold_type)
    error_message = "action.threshold_type must be 'PERCENTAGE' or 'ABSOLUTE_VALUE'."
  }

  validation {
    condition     = var.action == null || contains(["ACTUAL", "FORECASTED"], var.action.notification_type)
    error_message = "action.notification_type must be 'ACTUAL' or 'FORECASTED'."
  }

  validation {
    condition     = var.action == null || contains(["AUTOMATIC", "MANUAL"], var.action.approval_model)
    error_message = "action.approval_model must be 'AUTOMATIC' or 'MANUAL'."
  }

  validation {
    condition     = var.action == null || var.action.threshold_percent > 0
    error_message = "action.threshold_percent must be greater than 0."
  }

  validation {
    condition = (
      var.action == null ||
      try(var.action.ssm, null) == null ||
      contains(["STOP_EC2_INSTANCES", "STOP_RDS_INSTANCES"], var.action.ssm.action_sub_type)
    )
    error_message = "action.ssm.action_sub_type must be 'STOP_EC2_INSTANCES' or 'STOP_RDS_INSTANCES'."
  }

  validation {
    condition = (
      var.action == null ||
      try(var.action.ssm, null) == null ||
      length(var.action.ssm.instance_ids) > 0
    )
    error_message = "action.ssm.instance_ids must not be empty."
  }

  validation {
    condition = (
      var.action == null ||
      try(var.action.iam, null) == null ||
      length(var.action.iam.roles) + length(var.action.iam.groups) + length(var.action.iam.users) > 0
    )
    error_message = "action.iam must target at least one role, group, or user."
  }
}
