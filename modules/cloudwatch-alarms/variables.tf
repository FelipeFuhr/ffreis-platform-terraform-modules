variable "name_prefix" {
  description = "Prefix for all alarm names."
  type        = string
}

variable "alarm_actions" {
  description = "SNS topic ARNs to notify when an alarm fires."
  type        = list(string)
  default     = []
}

variable "ok_actions" {
  description = "SNS topic ARNs to notify when an alarm recovers."
  type        = list(string)
  default     = []
}

# ---------------------------------------------------------------------------
# Lambda alarms
# ---------------------------------------------------------------------------
variable "lambda_alarms" {
  description = "Map of Lambda function name → alarm thresholds."
  type = map(object({
    error_rate_threshold   = optional(number, 1)    # % of invocations that error
    throttle_threshold     = optional(number, 5)    # count per evaluation period
    duration_p99_threshold = optional(number, null) # ms — null = skip
    concurrent_threshold   = optional(number, null) # count — null = skip
  }))
  default = {}
}

# ---------------------------------------------------------------------------
# SQS alarms
# ---------------------------------------------------------------------------
variable "sqs_alarms" {
  description = "Map of SQS queue name → alarm thresholds."
  type = map(object({
    dlq_depth_threshold   = optional(number, 1)    # messages in DLQ
    queue_depth_threshold = optional(number, null) # messages visible — null = skip
    age_threshold_seconds = optional(number, null) # oldest message age — null = skip
  }))
  default = {}
}

# ---------------------------------------------------------------------------
# RDS alarms
# ---------------------------------------------------------------------------
variable "rds_alarms" {
  description = "Map of RDS instance identifier → alarm thresholds."
  type = map(object({
    cpu_threshold           = optional(number, 80)         # %
    free_storage_bytes      = optional(number, 5368709120) # 5 GiB
    connection_threshold    = optional(number, null)       # count — null = skip
    read_latency_threshold  = optional(number, null)       # seconds — null = skip
    write_latency_threshold = optional(number, null)       # seconds — null = skip
  }))
  default = {}
}

# ---------------------------------------------------------------------------
# ALB alarms
# ---------------------------------------------------------------------------
variable "alb_alarms" {
  description = "Map of ALB full name (load_balancer attribute) → alarm thresholds."
  type = map(object({
    error_5xx_threshold  = optional(number, 10) # count per period
    error_4xx_threshold  = optional(number, null)
    target_response_time = optional(number, 2) # seconds p95
  }))
  default = {}
}

# ---------------------------------------------------------------------------
# ECS alarms
# ---------------------------------------------------------------------------
variable "ecs_alarms" {
  description = "Map of 'cluster/service' → alarm thresholds."
  type = map(object({
    cpu_threshold    = optional(number, 80) # %
    memory_threshold = optional(number, 80) # %
  }))
  default = {}
}

variable "evaluation_periods" {
  description = "Number of periods over which data is compared to the threshold."
  type        = number
  default     = 3
}

variable "period_seconds" {
  description = "Period in seconds for each evaluation point."
  type        = number
  default     = 60
}

variable "tags" {
  description = "Tags applied to all alarms."
  type        = map(string)
  default     = {}
}
