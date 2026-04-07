locals {
  dlq_name = var.fifo_queue ? "${trimsuffix(var.name, ".fifo")}-dlq.fifo" : "${var.name}-dlq"
}

# ---------------------------------------------------------------------------
# Dead-Letter Queue
# ---------------------------------------------------------------------------
resource "aws_sqs_queue" "dlq" {
  count = var.create_dlq ? 1 : 0

  name                              = local.dlq_name
  fifo_queue                        = var.fifo_queue
  content_based_deduplication       = var.fifo_queue ? var.content_based_deduplication : null
  message_retention_seconds         = var.dlq_message_retention_seconds
  kms_master_key_id                 = var.kms_master_key_id
  kms_data_key_reuse_period_seconds = var.kms_data_key_reuse_period_seconds
  sqs_managed_sse_enabled           = var.kms_master_key_id == null ? true : null

  tags = merge(var.tags, { Role = "dlq" })
}

# ---------------------------------------------------------------------------
# Main queue
# ---------------------------------------------------------------------------
resource "aws_sqs_queue" "this" {
  name                              = var.name
  fifo_queue                        = var.fifo_queue
  content_based_deduplication       = var.fifo_queue ? var.content_based_deduplication : null
  visibility_timeout_seconds        = var.visibility_timeout_seconds
  message_retention_seconds         = var.message_retention_seconds
  max_message_size                  = var.max_message_size
  delay_seconds                     = var.delay_seconds
  receive_wait_time_seconds         = var.receive_wait_time_seconds
  kms_master_key_id                 = var.kms_master_key_id
  kms_data_key_reuse_period_seconds = var.kms_data_key_reuse_period_seconds
  sqs_managed_sse_enabled           = var.kms_master_key_id == null ? true : null

  redrive_policy = var.create_dlq ? jsonencode({
    deadLetterTargetArn = aws_sqs_queue.dlq[0].arn
    maxReceiveCount     = var.max_receive_count
  }) : null

  tags = var.tags
}

resource "aws_sqs_queue_policy" "this" {
  count     = var.policy != null ? 1 : 0
  queue_url = aws_sqs_queue.this.id
  policy    = var.policy
}
