output "queue_id" {
  description = "Queue URL (used as the queue ID)."
  value       = aws_sqs_queue.this.id
}

output "queue_arn" {
  description = "Queue ARN."
  value       = aws_sqs_queue.this.arn
}

output "queue_name" {
  description = "Queue name."
  value       = aws_sqs_queue.this.name
}

output "dlq_arn" {
  description = "DLQ ARN (empty if create_dlq = false)."
  value       = var.create_dlq ? aws_sqs_queue.dlq[0].arn : ""
}

output "dlq_id" {
  description = "DLQ URL (empty if create_dlq = false)."
  value       = var.create_dlq ? aws_sqs_queue.dlq[0].id : ""
}
