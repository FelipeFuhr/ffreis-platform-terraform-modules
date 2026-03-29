output "id" {
  description = "Table name."
  value       = aws_dynamodb_table.this.id
}

output "arn" {
  description = "Table ARN."
  value       = aws_dynamodb_table.this.arn
}

output "stream_arn" {
  description = "DynamoDB Streams ARN (empty string when streams are disabled)."
  value       = aws_dynamodb_table.this.stream_arn
}
