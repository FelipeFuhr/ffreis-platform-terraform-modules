resource "aws_kinesis_stream" "this" {
  name             = var.name
  retention_period = var.retention_period

  stream_mode_details {
    stream_mode = var.stream_mode
  }

  shard_count = var.stream_mode == "PROVISIONED" ? var.shard_count : null

  encryption_type = "KMS"
  kms_key_id      = var.kms_key_id

  shard_level_metrics = var.shard_level_metrics

  tags = var.tags
}
