locals {
  create_execution_role = var.task_execution_role_arn == null
  create_task_role      = var.task_role_arn == null
  autoscaling_enabled   = var.autoscaling_min_capacity != null

  iam_effect_allow           = "Allow"
  iam_action_sts_assume_role = "sts:AssumeRole"
  iam_principal_type_service = "Service"
}

# ---------------------------------------------------------------------------
# Task execution role (pull images, write CloudWatch logs)
# ---------------------------------------------------------------------------
data "aws_iam_policy_document" "ecs_assume" {
  statement {
    effect  = local.iam_effect_allow
    actions = [local.iam_action_sts_assume_role]
    principals {
      type        = local.iam_principal_type_service
      identifiers = ["ecs-tasks.amazonaws.com"]
    }
  }
}

resource "aws_iam_role" "execution" {
  count              = local.create_execution_role ? 1 : 0
  name               = "${var.name}-exec"
  assume_role_policy = data.aws_iam_policy_document.ecs_assume.json
  tags               = var.tags
}

resource "aws_iam_role_policy_attachment" "execution" {
  count      = local.create_execution_role ? 1 : 0
  role       = aws_iam_role.execution[0].name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AmazonECSTaskExecutionRolePolicy"
}

# ---------------------------------------------------------------------------
# Task role (what the running container can call in AWS)
# ---------------------------------------------------------------------------
resource "aws_iam_role" "task" {
  count              = local.create_task_role ? 1 : 0
  name               = "${var.name}-task"
  assume_role_policy = data.aws_iam_policy_document.ecs_assume.json
  tags               = var.tags
}

resource "aws_iam_role_policy_attachment" "task_managed" {
  for_each   = local.create_task_role ? toset(var.task_role_managed_policy_arns) : toset([])
  role       = aws_iam_role.task[0].name
  policy_arn = each.value
}

resource "aws_iam_role_policy" "task_inline" {
  for_each = local.create_task_role ? var.task_role_inline_policies : {}
  name     = each.key
  role     = aws_iam_role.task[0].id
  policy   = each.value
}

# ---------------------------------------------------------------------------
# Task definition
# ---------------------------------------------------------------------------
resource "aws_ecs_task_definition" "this" {
  family                   = var.name
  cpu                      = var.cpu
  memory                   = var.memory
  network_mode             = var.network_mode
  requires_compatibilities = var.requires_compatibilities
  container_definitions    = var.container_definitions

  execution_role_arn = local.create_execution_role ? aws_iam_role.execution[0].arn : var.task_execution_role_arn
  task_role_arn      = local.create_task_role ? aws_iam_role.task[0].arn : var.task_role_arn

  runtime_platform {
    operating_system_family = var.runtime_platform.operating_system_family
    cpu_architecture        = var.runtime_platform.cpu_architecture
  }

  dynamic "volume" {
    for_each = var.volumes
    content {
      name = volume.value.name

      dynamic "efs_volume_configuration" {
        for_each = volume.value.efs_volume_configuration != null ? [volume.value.efs_volume_configuration] : []
        content {
          file_system_id     = efs_volume_configuration.value.file_system_id
          root_directory     = efs_volume_configuration.value.root_directory
          transit_encryption = efs_volume_configuration.value.transit_encryption

          dynamic "authorization_config" {
            for_each = efs_volume_configuration.value.authorization_config != null ? [efs_volume_configuration.value.authorization_config] : []
            content {
              access_point_id = authorization_config.value.access_point_id
              iam             = authorization_config.value.iam
            }
          }
        }
      }
    }
  }

  tags = var.tags
}

# ---------------------------------------------------------------------------
# ECS service
# ---------------------------------------------------------------------------
resource "aws_ecs_service" "this" {
  name            = var.name
  cluster         = var.cluster_arn
  task_definition = aws_ecs_task_definition.this.arn
  desired_count   = var.desired_count

  deployment_minimum_healthy_percent = var.deployment_minimum_healthy_percent
  deployment_maximum_percent         = var.deployment_maximum_percent
  enable_execute_command             = var.enable_execute_command
  propagate_tags                     = var.propagate_tags
  health_check_grace_period_seconds  = length(var.load_balancers) > 0 ? var.health_check_grace_period_seconds : null

  network_configuration {
    subnets          = var.subnet_ids
    security_groups  = var.security_group_ids
    assign_public_ip = var.assign_public_ip
  }

  dynamic "capacity_provider_strategy" {
    for_each = var.capacity_provider_strategy
    content {
      capacity_provider = capacity_provider_strategy.value.capacity_provider
      weight            = capacity_provider_strategy.value.weight
      base              = capacity_provider_strategy.value.base
    }
  }

  dynamic "load_balancer" {
    for_each = var.load_balancers
    content {
      target_group_arn = load_balancer.value.target_group_arn
      container_name   = load_balancer.value.container_name
      container_port   = load_balancer.value.container_port
    }
  }

  deployment_circuit_breaker {
    enable   = true
    rollback = true
  }

  tags = var.tags

  lifecycle {
    ignore_changes = [desired_count] # Managed by auto-scaling
  }
}

# ---------------------------------------------------------------------------
# Auto-scaling
# ---------------------------------------------------------------------------
resource "aws_appautoscaling_target" "this" {
  count              = local.autoscaling_enabled ? 1 : 0
  service_namespace  = "ecs"
  resource_id        = "service/${split("/", var.cluster_arn)[1]}/${var.name}"
  scalable_dimension = "ecs:service:DesiredCount"
  min_capacity       = var.autoscaling_min_capacity
  max_capacity       = var.autoscaling_max_capacity
  depends_on         = [aws_ecs_service.this]
}

resource "aws_appautoscaling_policy" "cpu" {
  count              = local.autoscaling_enabled && var.autoscaling_cpu_target != null ? 1 : 0
  name               = "${var.name}-cpu-scaling"
  service_namespace  = "ecs"
  resource_id        = aws_appautoscaling_target.this[0].resource_id
  scalable_dimension = aws_appautoscaling_target.this[0].scalable_dimension
  policy_type        = "TargetTrackingScaling"

  target_tracking_scaling_policy_configuration {
    target_value       = var.autoscaling_cpu_target
    scale_in_cooldown  = 300
    scale_out_cooldown = 60

    predefined_metric_specification {
      predefined_metric_type = "ECSServiceAverageCPUUtilization"
    }
  }
}

resource "aws_appautoscaling_policy" "memory" {
  count              = local.autoscaling_enabled && var.autoscaling_memory_target != null ? 1 : 0
  name               = "${var.name}-memory-scaling"
  service_namespace  = "ecs"
  resource_id        = aws_appautoscaling_target.this[0].resource_id
  scalable_dimension = aws_appautoscaling_target.this[0].scalable_dimension
  policy_type        = "TargetTrackingScaling"

  target_tracking_scaling_policy_configuration {
    target_value       = var.autoscaling_memory_target
    scale_in_cooldown  = 300
    scale_out_cooldown = 60

    predefined_metric_specification {
      predefined_metric_type = "ECSServiceAverageMemoryUtilization"
    }
  }
}
