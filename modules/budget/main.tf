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
