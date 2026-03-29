output "lambda_alarm_arns" {
  description = "Map of alarm name → ARN for all Lambda alarms."
  value = merge(
    { for k, v in aws_cloudwatch_metric_alarm.lambda_errors : v.alarm_name => v.arn },
    { for k, v in aws_cloudwatch_metric_alarm.lambda_throttles : v.alarm_name => v.arn },
    { for k, v in aws_cloudwatch_metric_alarm.lambda_duration : v.alarm_name => v.arn },
  )
}

output "sqs_alarm_arns" {
  description = "Map of alarm name → ARN for all SQS alarms."
  value = merge(
    { for k, v in aws_cloudwatch_metric_alarm.sqs_dlq_depth : v.alarm_name => v.arn },
    { for k, v in aws_cloudwatch_metric_alarm.sqs_age : v.alarm_name => v.arn },
  )
}

output "rds_alarm_arns" {
  description = "Map of alarm name → ARN for all RDS alarms."
  value = merge(
    { for k, v in aws_cloudwatch_metric_alarm.rds_cpu : v.alarm_name => v.arn },
    { for k, v in aws_cloudwatch_metric_alarm.rds_storage : v.alarm_name => v.arn },
  )
}

output "alb_alarm_arns" {
  description = "Map of alarm name → ARN for all ALB alarms."
  value = merge(
    { for k, v in aws_cloudwatch_metric_alarm.alb_5xx : v.alarm_name => v.arn },
    { for k, v in aws_cloudwatch_metric_alarm.alb_target_response_time : v.alarm_name => v.arn },
  )
}

output "ecs_alarm_arns" {
  description = "Map of alarm name → ARN for all ECS alarms."
  value = merge(
    { for k, v in aws_cloudwatch_metric_alarm.ecs_cpu : v.alarm_name => v.arn },
    { for k, v in aws_cloudwatch_metric_alarm.ecs_memory : v.alarm_name => v.arn },
  )
}
