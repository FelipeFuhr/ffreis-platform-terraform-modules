locals {
  port = var.port != null ? var.port : (var.engine == "postgres" ? 5432 : 3306)

  # Enhanced monitoring requires an IAM role.
  create_monitoring_role = var.monitoring_interval > 0

  # Enable CloudWatch log exports by default so the instance isn't created without logging.
  # The caller can override with var.enabled_cloudwatch_logs_exports.
  default_cloudwatch_logs_exports = var.engine == "postgres" ? ["postgresql", "upgrade"] : ["error", "general", "slowquery"]
  cloudwatch_logs_exports         = length(var.enabled_cloudwatch_logs_exports) > 0 ? var.enabled_cloudwatch_logs_exports : local.default_cloudwatch_logs_exports

  iam_effect_allow           = "Allow"
  iam_action_sts_assume_role = "sts:AssumeRole"
  iam_principal_type_service = "Service"
}

# ---------------------------------------------------------------------------
# Enhanced monitoring IAM role
# ---------------------------------------------------------------------------
data "aws_iam_policy_document" "monitoring_assume" {
  count = local.create_monitoring_role ? 1 : 0

  statement {
    effect  = local.iam_effect_allow
    actions = [local.iam_action_sts_assume_role]
    principals {
      type        = local.iam_principal_type_service
      identifiers = ["monitoring.rds.amazonaws.com"]
    }
  }
}

resource "aws_iam_role" "monitoring" {
  count              = local.create_monitoring_role ? 1 : 0
  name               = "${var.identifier}-rds-monitoring"
  assume_role_policy = data.aws_iam_policy_document.monitoring_assume[0].json
  tags               = var.tags
}

resource "aws_iam_role_policy_attachment" "monitoring" {
  count      = local.create_monitoring_role ? 1 : 0
  role       = aws_iam_role.monitoring[0].name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AmazonRDSEnhancedMonitoringRole"
}

# ---------------------------------------------------------------------------
# RDS instance
# ---------------------------------------------------------------------------
resource "aws_db_instance" "this" {
  #checkov:skip=CKV2_AWS_30:Query logging is engine-specific and typically enforced via parameter groups at the stack level.
  identifier = var.identifier

  engine         = var.engine
  engine_version = var.engine_version
  instance_class = var.instance_class
  port           = local.port

  allocated_storage     = var.allocated_storage
  max_allocated_storage = var.max_allocated_storage > 0 ? var.max_allocated_storage : null
  storage_type          = var.storage_type
  storage_encrypted     = var.storage_encrypted
  kms_key_id            = var.kms_key_id

  db_name  = var.db_name
  username = var.username
  password = var.manage_master_user_password ? null : var.password

  manage_master_user_password   = var.manage_master_user_password
  master_user_secret_kms_key_id = var.manage_master_user_password ? var.master_user_secret_kms_key_id : null

  multi_az               = var.multi_az
  db_subnet_group_name   = var.db_subnet_group_name
  vpc_security_group_ids = var.vpc_security_group_ids
  publicly_accessible    = var.publicly_accessible

  deletion_protection       = var.deletion_protection
  skip_final_snapshot       = var.skip_final_snapshot
  final_snapshot_identifier = var.skip_final_snapshot ? null : coalesce(var.final_snapshot_identifier, "${var.identifier}-final-snapshot")

  backup_retention_period    = var.backup_retention_period
  backup_window              = var.backup_window
  maintenance_window         = var.maintenance_window
  auto_minor_version_upgrade = var.auto_minor_version_upgrade
  apply_immediately          = var.apply_immediately

  parameter_group_name = var.parameter_group_name
  option_group_name    = var.option_group_name

  enabled_cloudwatch_logs_exports = local.cloudwatch_logs_exports

  iam_database_authentication_enabled = var.iam_database_authentication_enabled

  monitoring_interval = var.monitoring_interval
  monitoring_role_arn = local.create_monitoring_role ? aws_iam_role.monitoring[0].arn : null

  performance_insights_enabled          = var.performance_insights_enabled
  performance_insights_kms_key_id       = var.performance_insights_enabled ? var.performance_insights_kms_key_id : null
  performance_insights_retention_period = var.performance_insights_enabled ? var.performance_insights_retention_period : null

  ca_cert_identifier = var.ca_cert_identifier

  copy_tags_to_snapshot = true

  tags = var.tags
}
