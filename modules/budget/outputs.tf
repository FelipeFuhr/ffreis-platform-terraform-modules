output "id" {
  description = "Budget ID."
  value       = aws_budgets_budget.this.id
}

output "name" {
  description = "Budget name."
  value       = aws_budgets_budget.this.name
}

output "action_id" {
  description = "Budget action ID, or null when no enforcement action is configured (var.action = null)."
  value       = local.action_enabled ? aws_budgets_budget_action.this[0].action_id : null
}

output "action_execution_role_arn" {
  description = "Role AWS Budgets assumes to apply the action, or null when no action is configured."
  value       = local.action_role_arn
}

output "action_enforces" {
  description = <<-EOT
    True only when this budget can actually stop spend: an action exists AND it
    is AUTOMATIC. A MANUAL action waits for a human, so it enforces nothing on
    its own — assert on this in a policy check rather than on action_id.
  EOT
  # try(..., false) rather than `local.action_enabled && var.action.approval_model
  # == "AUTOMATIC"`. An output has no `count`, so it is ALWAYS evaluated, and
  # `&&` does not short-circuit: with var.action null the right operand still
  # ran and failed the plan with "Attempt to get attribute from null value" —
  # breaking the notify-only default for every existing caller.
  #
  # The rule, consistent across this module: `? :` evaluates its branches
  # lazily (which is why action_id's ternary is fine), while `&&` and `||` do
  # not. So a null guard has to be structural — try() — not positional.
  value = try(var.action.approval_model == "AUTOMATIC", false)
}
