locals {
  sns_kms_key_id = var.kms_master_key_id != null ? var.kms_master_key_id : "alias/aws/sns"
}

resource "aws_sns_topic" "this" {
  name                        = var.name
  fifo_topic                  = var.fifo_topic
  content_based_deduplication = var.fifo_topic ? var.content_based_deduplication : null
  display_name                = var.display_name != "" ? var.display_name : null
  kms_master_key_id           = local.sns_kms_key_id
  policy                      = var.policy
  delivery_policy             = var.delivery_policy

  tags = var.tags
}

resource "aws_sns_topic_subscription" "this" {
  for_each = var.subscriptions

  topic_arn                       = aws_sns_topic.this.arn
  protocol                        = each.value.protocol
  endpoint                        = each.value.endpoint
  raw_message_delivery            = each.value.raw_message_delivery
  filter_policy                   = each.value.filter_policy
  filter_policy_scope             = each.value.filter_policy != null ? each.value.filter_policy_scope : null
  confirmation_timeout_in_minutes = each.value.confirmation_timeout_in_minutes
  endpoint_auto_confirms          = each.value.endpoint_auto_confirms
}
