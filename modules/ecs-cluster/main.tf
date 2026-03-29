resource "aws_ecs_cluster" "this" {
  name = var.name

  setting {
    name  = "containerInsights"
    value = var.enable_container_insights ? "enabled" : "disabled"
  }

  dynamic "configuration" {
    for_each = (
      var.execute_command_kms_key_arn != null ||
      var.execute_command_log_group_name != null ||
      var.execute_command_s3_bucket != null
    ) ? [1] : []
    content {
      execute_command_configuration {
        kms_key_id = var.execute_command_kms_key_arn
        logging    = "OVERRIDE"

        log_configuration {
          cloud_watch_encryption_enabled = var.execute_command_kms_key_arn != null
          cloud_watch_log_group_name     = var.execute_command_log_group_name
          s3_bucket_name                 = var.execute_command_s3_bucket
          s3_key_prefix                  = var.execute_command_s3_bucket != null ? "ecs-exec" : null
        }
      }
    }
  }

  tags = var.tags
}

resource "aws_ecs_cluster_capacity_providers" "this" {
  cluster_name       = aws_ecs_cluster.this.name
  capacity_providers = var.capacity_providers

  dynamic "default_capacity_provider_strategy" {
    for_each = var.default_capacity_provider_strategy
    content {
      capacity_provider = default_capacity_provider_strategy.value.capacity_provider
      weight            = default_capacity_provider_strategy.value.weight
      base              = default_capacity_provider_strategy.value.base
    }
  }
}
