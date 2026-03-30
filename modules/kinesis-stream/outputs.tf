output "name" {
  description = "Stream name."
  value       = aws_kinesis_stream.this.name
}

output "arn" {
  description = "Stream ARN."
  value       = aws_kinesis_stream.this.arn
}

output "shard_count" {
  description = "Current shard count (null for ON_DEMAND)."
  value       = aws_kinesis_stream.this.shard_count
}
