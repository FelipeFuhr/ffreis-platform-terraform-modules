# ---------------------------------------------------------------------------
# Lambda alarms
# ---------------------------------------------------------------------------
resource "aws_cloudwatch_metric_alarm" "lambda_errors" {
  for_each = var.lambda_alarms

  alarm_name          = "${var.name_prefix}-lambda-${each.key}-errors"
  alarm_description   = "Lambda ${each.key} error rate exceeded ${each.value.error_rate_threshold}%"
  namespace           = "AWS/Lambda"
  metric_name         = "Errors"
  dimensions          = { FunctionName = each.key }
  statistic           = "Sum"
  period              = var.period_seconds
  evaluation_periods  = var.evaluation_periods
  threshold           = each.value.error_rate_threshold
  comparison_operator = "GreaterThanOrEqualToThreshold"
  treat_missing_data  = "notBreaching"

  alarm_actions = var.alarm_actions
  ok_actions    = var.ok_actions
  tags          = var.tags
}

resource "aws_cloudwatch_metric_alarm" "lambda_throttles" {
  for_each = var.lambda_alarms

  alarm_name          = "${var.name_prefix}-lambda-${each.key}-throttles"
  alarm_description   = "Lambda ${each.key} throttling exceeded ${each.value.throttle_threshold}"
  namespace           = "AWS/Lambda"
  metric_name         = "Throttles"
  dimensions          = { FunctionName = each.key }
  statistic           = "Sum"
  period              = var.period_seconds
  evaluation_periods  = var.evaluation_periods
  threshold           = each.value.throttle_threshold
  comparison_operator = "GreaterThanOrEqualToThreshold"
  treat_missing_data  = "notBreaching"

  alarm_actions = var.alarm_actions
  ok_actions    = var.ok_actions
  tags          = var.tags
}

resource "aws_cloudwatch_metric_alarm" "lambda_duration" {
  for_each = { for k, v in var.lambda_alarms : k => v if v.duration_p99_threshold != null }

  alarm_name          = "${var.name_prefix}-lambda-${each.key}-duration-p99"
  alarm_description   = "Lambda ${each.key} p99 duration exceeded ${each.value.duration_p99_threshold}ms"
  namespace           = "AWS/Lambda"
  metric_name         = "Duration"
  dimensions          = { FunctionName = each.key }
  extended_statistic  = "p99"
  period              = var.period_seconds
  evaluation_periods  = var.evaluation_periods
  threshold           = each.value.duration_p99_threshold
  comparison_operator = "GreaterThanOrEqualToThreshold"
  treat_missing_data  = "notBreaching"

  alarm_actions = var.alarm_actions
  ok_actions    = var.ok_actions
  tags          = var.tags
}

# ---------------------------------------------------------------------------
# SQS alarms
# ---------------------------------------------------------------------------
resource "aws_cloudwatch_metric_alarm" "sqs_dlq_depth" {
  for_each = var.sqs_alarms

  alarm_name          = "${var.name_prefix}-sqs-${each.key}-dlq-depth"
  alarm_description   = "Messages appeared in DLQ for ${each.key}"
  namespace           = "AWS/SQS"
  metric_name         = "ApproximateNumberOfMessagesVisible"
  dimensions          = { QueueName = "${each.key}-dlq" }
  statistic           = "Maximum"
  period              = var.period_seconds
  evaluation_periods  = 1
  threshold           = each.value.dlq_depth_threshold
  comparison_operator = "GreaterThanOrEqualToThreshold"
  treat_missing_data  = "notBreaching"

  alarm_actions = var.alarm_actions
  ok_actions    = var.ok_actions
  tags          = var.tags
}

resource "aws_cloudwatch_metric_alarm" "sqs_age" {
  for_each = { for k, v in var.sqs_alarms : k => v if v.age_threshold_seconds != null }

  alarm_name          = "${var.name_prefix}-sqs-${each.key}-message-age"
  alarm_description   = "Oldest message in ${each.key} exceeded ${each.value.age_threshold_seconds}s"
  namespace           = "AWS/SQS"
  metric_name         = "ApproximateAgeOfOldestMessage"
  dimensions          = { QueueName = each.key }
  statistic           = "Maximum"
  period              = var.period_seconds
  evaluation_periods  = var.evaluation_periods
  threshold           = each.value.age_threshold_seconds
  comparison_operator = "GreaterThanOrEqualToThreshold"
  treat_missing_data  = "notBreaching"

  alarm_actions = var.alarm_actions
  ok_actions    = var.ok_actions
  tags          = var.tags
}

# ---------------------------------------------------------------------------
# RDS alarms
# ---------------------------------------------------------------------------
resource "aws_cloudwatch_metric_alarm" "rds_cpu" {
  for_each = var.rds_alarms

  alarm_name          = "${var.name_prefix}-rds-${each.key}-cpu"
  alarm_description   = "RDS ${each.key} CPU exceeded ${each.value.cpu_threshold}%"
  namespace           = "AWS/RDS"
  metric_name         = "CPUUtilization"
  dimensions          = { DBInstanceIdentifier = each.key }
  statistic           = "Average"
  period              = var.period_seconds
  evaluation_periods  = var.evaluation_periods
  threshold           = each.value.cpu_threshold
  comparison_operator = "GreaterThanOrEqualToThreshold"
  treat_missing_data  = "notBreaching"

  alarm_actions = var.alarm_actions
  ok_actions    = var.ok_actions
  tags          = var.tags
}

resource "aws_cloudwatch_metric_alarm" "rds_storage" {
  for_each = var.rds_alarms

  alarm_name          = "${var.name_prefix}-rds-${each.key}-free-storage"
  alarm_description   = "RDS ${each.key} free storage below threshold"
  namespace           = "AWS/RDS"
  metric_name         = "FreeStorageSpace"
  dimensions          = { DBInstanceIdentifier = each.key }
  statistic           = "Minimum"
  period              = var.period_seconds
  evaluation_periods  = var.evaluation_periods
  threshold           = each.value.free_storage_bytes
  comparison_operator = "LessThanOrEqualToThreshold"
  treat_missing_data  = "notBreaching"

  alarm_actions = var.alarm_actions
  ok_actions    = var.ok_actions
  tags          = var.tags
}

# ---------------------------------------------------------------------------
# ALB alarms
# ---------------------------------------------------------------------------
resource "aws_cloudwatch_metric_alarm" "alb_5xx" {
  for_each = var.alb_alarms

  alarm_name          = "${var.name_prefix}-alb-${each.key}-5xx"
  alarm_description   = "ALB ${each.key} 5xx errors exceeded ${each.value.error_5xx_threshold}"
  namespace           = "AWS/ApplicationELB"
  metric_name         = "HTTPCode_ELB_5XX_Count"
  dimensions          = { LoadBalancer = each.key }
  statistic           = "Sum"
  period              = var.period_seconds
  evaluation_periods  = var.evaluation_periods
  threshold           = each.value.error_5xx_threshold
  comparison_operator = "GreaterThanOrEqualToThreshold"
  treat_missing_data  = "notBreaching"

  alarm_actions = var.alarm_actions
  ok_actions    = var.ok_actions
  tags          = var.tags
}

resource "aws_cloudwatch_metric_alarm" "alb_target_response_time" {
  for_each = var.alb_alarms

  alarm_name          = "${var.name_prefix}-alb-${each.key}-p95-latency"
  alarm_description   = "ALB ${each.key} p95 response time exceeded ${each.value.target_response_time}s"
  namespace           = "AWS/ApplicationELB"
  metric_name         = "TargetResponseTime"
  dimensions          = { LoadBalancer = each.key }
  extended_statistic  = "p95"
  period              = var.period_seconds
  evaluation_periods  = var.evaluation_periods
  threshold           = each.value.target_response_time
  comparison_operator = "GreaterThanOrEqualToThreshold"
  treat_missing_data  = "notBreaching"

  alarm_actions = var.alarm_actions
  ok_actions    = var.ok_actions
  tags          = var.tags
}

# ---------------------------------------------------------------------------
# ECS alarms
# ---------------------------------------------------------------------------
locals {
  ecs_alarms_flat = {
    for key, v in var.ecs_alarms : key => {
      cluster = split("/", key)[0]
      service = split("/", key)[1]
      config  = v
    }
  }
}

resource "aws_cloudwatch_metric_alarm" "ecs_cpu" {
  for_each = local.ecs_alarms_flat

  alarm_name          = "${var.name_prefix}-ecs-${each.value.service}-cpu"
  alarm_description   = "ECS service ${each.value.service} CPU exceeded ${each.value.config.cpu_threshold}%"
  namespace           = "AWS/ECS"
  metric_name         = "CPUUtilization"
  dimensions = {
    ClusterName = each.value.cluster
    ServiceName = each.value.service
  }
  statistic           = "Average"
  period              = var.period_seconds
  evaluation_periods  = var.evaluation_periods
  threshold           = each.value.config.cpu_threshold
  comparison_operator = "GreaterThanOrEqualToThreshold"
  treat_missing_data  = "notBreaching"

  alarm_actions = var.alarm_actions
  ok_actions    = var.ok_actions
  tags          = var.tags
}

resource "aws_cloudwatch_metric_alarm" "ecs_memory" {
  for_each = local.ecs_alarms_flat

  alarm_name          = "${var.name_prefix}-ecs-${each.value.service}-memory"
  alarm_description   = "ECS service ${each.value.service} memory exceeded ${each.value.config.memory_threshold}%"
  namespace           = "AWS/ECS"
  metric_name         = "MemoryUtilization"
  dimensions = {
    ClusterName = each.value.cluster
    ServiceName = each.value.service
  }
  statistic           = "Average"
  period              = var.period_seconds
  evaluation_periods  = var.evaluation_periods
  threshold           = each.value.config.memory_threshold
  comparison_operator = "GreaterThanOrEqualToThreshold"
  treat_missing_data  = "notBreaching"

  alarm_actions = var.alarm_actions
  ok_actions    = var.ok_actions
  tags          = var.tags
}
