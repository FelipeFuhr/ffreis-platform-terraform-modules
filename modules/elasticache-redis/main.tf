resource "aws_elasticache_replication_group" "this" {
  replication_group_id = var.cluster_id
  description          = var.description

  node_type          = var.node_type
  engine_version     = var.engine_version
  num_cache_clusters = var.num_cache_clusters
  port               = var.port

  automatic_failover_enabled = var.automatic_failover_enabled
  multi_az_enabled           = var.multi_az_enabled

  subnet_group_name  = var.subnet_group_name
  security_group_ids = var.security_group_ids

  at_rest_encryption_enabled = var.at_rest_encryption_enabled
  kms_key_id                 = var.at_rest_encryption_enabled ? var.kms_key_id : null

  transit_encryption_enabled = var.transit_encryption_enabled
  transit_encryption_mode    = var.transit_encryption_enabled ? var.transit_encryption_mode : null
  auth_token                 = var.transit_encryption_enabled ? var.auth_token : null

  parameter_group_name = var.parameter_group_name
  apply_immediately    = var.apply_immediately
  maintenance_window   = var.maintenance_window

  snapshot_retention_limit = var.snapshot_retention_limit
  snapshot_window          = var.snapshot_retention_limit > 0 ? var.snapshot_window : null

  auto_minor_version_upgrade = var.auto_minor_version_upgrade
  notification_topic_arn     = var.notification_topic_arn

  tags = var.tags
}
