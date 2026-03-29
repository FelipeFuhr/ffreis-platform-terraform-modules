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
    threshold_percent    = number
    comparison_operator  = optional(string, "GREATER_THAN")
    threshold_type       = optional(string, "PERCENTAGE")
    notification_type    = optional(string, "ACTUAL")
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
