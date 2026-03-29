locals {
  # Merge caller-provided attribute definitions with the key attributes so
  # callers don't have to repeat them.
  key_attribute_names = compact([var.hash_key, var.range_key])

  extra_attributes = [
    for a in var.attributes : a
    if !contains(local.key_attribute_names, a.name)
  ]

  all_attributes = concat(
    [{ name = var.hash_key, type = "S" }],
    var.range_key != "" ? [{ name = var.range_key, type = "S" }] : [],
    local.extra_attributes,
  )
}

resource "aws_dynamodb_table" "this" {
  name         = var.name
  billing_mode = var.billing_mode
  hash_key     = var.hash_key
  range_key    = var.range_key != "" ? var.range_key : null

  read_capacity  = var.billing_mode == "PROVISIONED" ? var.read_capacity : null
  write_capacity = var.billing_mode == "PROVISIONED" ? var.write_capacity : null

  dynamic "attribute" {
    for_each = local.all_attributes
    content {
      name = attribute.value.name
      type = attribute.value.type
    }
  }

  # Point-in-time recovery — always enabled. Provides a 35-day recovery window
  # with no performance impact and at minimal cost.
  point_in_time_recovery {
    enabled = true
  }

  # Server-side encryption. Defaults to the AWS-managed DynamoDB key (free).
  # Pass kms_master_key_id to use a customer-managed key for stricter controls.
  server_side_encryption {
    enabled     = true
    kms_key_arn = var.kms_master_key_id
  }

  dynamic "global_secondary_index" {
    for_each = var.global_secondary_indexes
    content {
      name               = global_secondary_index.value.name
      hash_key           = global_secondary_index.value.hash_key
      range_key          = global_secondary_index.value.range_key
      projection_type    = global_secondary_index.value.projection_type
      non_key_attributes = global_secondary_index.value.projection_type == "INCLUDE" ? global_secondary_index.value.non_key_attributes : null
      read_capacity      = var.billing_mode == "PROVISIONED" ? global_secondary_index.value.read_capacity : null
      write_capacity     = var.billing_mode == "PROVISIONED" ? global_secondary_index.value.write_capacity : null
    }
  }

  dynamic "ttl" {
    for_each = var.ttl_attribute != "" ? [var.ttl_attribute] : []
    content {
      attribute_name = ttl.value
      enabled        = true
    }
  }

  stream_enabled   = var.stream_enabled
  stream_view_type = var.stream_enabled ? var.stream_view_type : null

  tags = var.tags
}
