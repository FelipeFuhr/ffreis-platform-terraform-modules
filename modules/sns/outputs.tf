output "arn" {
  description = "SNS topic ARN."
  value       = aws_sns_topic.this.arn
}

output "name" {
  description = "SNS topic name."
  value       = aws_sns_topic.this.name
}

output "subscription_arns" {
  description = "Map of subscription name → subscription ARN."
  value       = { for k, v in aws_sns_topic_subscription.this : k => v.arn }
}
