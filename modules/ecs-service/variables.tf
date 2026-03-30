variable "name" {
  description = "ECS service name."
  type        = string
}

variable "cluster_arn" {
  description = "ARN of the ECS cluster."
  type        = string
}

variable "desired_count" {
  description = "Number of tasks to run."
  type        = number
  default     = 1
}

# ---------------------------------------------------------------------------
# Task definition
# ---------------------------------------------------------------------------
variable "cpu" {
  description = "Task CPU units (256, 512, 1024, 2048, 4096)."
  type        = number
  default     = 256
}

variable "memory" {
  description = "Task memory in MiB."
  type        = number
  default     = 512
}

variable "container_definitions" {
  description = "JSON array of container definitions. Use jsonencode()."
  type        = string
}

variable "task_execution_role_arn" {
  description = "IAM role ARN for the ECS task execution role (pull images, write logs). Leave null to create one."
  type        = string
  default     = null
}

variable "task_role_arn" {
  description = "IAM role ARN the running task assumes for AWS API calls. Leave null to create one."
  type        = string
  default     = null
}

variable "task_role_inline_policies" {
  description = "Map of inline policy name → JSON for the task role (used when task_role_arn = null)."
  type        = map(string)
  default     = {}
}

variable "task_role_managed_policy_arns" {
  description = "Managed policy ARNs for the task role (used when task_role_arn = null)."
  type        = list(string)
  default     = []
}

variable "requires_compatibilities" {
  description = "Launch types: ['FARGATE'] or ['EC2']."
  type        = list(string)
  default     = ["FARGATE"]
}

variable "network_mode" {
  description = "Task network mode. Fargate requires 'awsvpc'."
  type        = string
  default     = "awsvpc"
}

variable "runtime_platform" {
  description = "OS family and CPU architecture for Fargate."
  type = object({
    operating_system_family = optional(string, "LINUX")
    cpu_architecture        = optional(string, "ARM64")
  })
  default = {}
}

variable "volumes" {
  description = "EFS or bind-mount volumes to attach to the task."
  type = list(object({
    name = string
    efs_volume_configuration = optional(object({
      file_system_id     = string
      root_directory     = optional(string, "/")
      transit_encryption = optional(string, "ENABLED")
      authorization_config = optional(object({
        access_point_id = optional(string, null)
        iam             = optional(string, "ENABLED")
      }), null)
    }), null)
  }))
  default = []
}

# ---------------------------------------------------------------------------
# Networking
# ---------------------------------------------------------------------------
variable "subnet_ids" {
  description = "Subnet IDs for the awsvpc network interface (private subnets recommended)."
  type        = list(string)
}

variable "security_group_ids" {
  description = "Security group IDs attached to the task ENI."
  type        = list(string)
}

variable "assign_public_ip" {
  description = "Assign a public IP to the task ENI. Required for Fargate in public subnets without NAT."
  type        = bool
  default     = false
}

# ---------------------------------------------------------------------------
# Load balancer integration
# ---------------------------------------------------------------------------
variable "load_balancers" {
  description = "List of ALB/NLB target group associations."
  type = list(object({
    target_group_arn = string
    container_name   = string
    container_port   = number
  }))
  default = []
}

variable "health_check_grace_period_seconds" {
  description = "Grace period after task start before ALB health checks matter."
  type        = number
  default     = 30
}

# ---------------------------------------------------------------------------
# Capacity provider
# ---------------------------------------------------------------------------
variable "capacity_provider_strategy" {
  description = "Capacity provider strategy. Defaults to FARGATE_SPOT with FARGATE base."
  type = list(object({
    capacity_provider = string
    weight            = optional(number, 1)
    base              = optional(number, 0)
  }))
  default = [
    { capacity_provider = "FARGATE", weight = 1, base = 1 },
    { capacity_provider = "FARGATE_SPOT", weight = 4, base = 0 },
  ]
}

# ---------------------------------------------------------------------------
# Auto-scaling
# ---------------------------------------------------------------------------
variable "autoscaling_min_capacity" {
  description = "Minimum task count for auto-scaling. null = no auto-scaling."
  type        = number
  default     = null
}

variable "autoscaling_max_capacity" {
  description = "Maximum task count for auto-scaling."
  type        = number
  default     = null
}

variable "autoscaling_cpu_target" {
  description = "Target CPU utilisation percentage for auto-scaling. null = no CPU scaling."
  type        = number
  default     = 70
}

variable "autoscaling_memory_target" {
  description = "Target memory utilisation percentage for auto-scaling. null = no memory scaling."
  type        = number
  default     = 80
}

# ---------------------------------------------------------------------------
# Deployment
# ---------------------------------------------------------------------------
variable "deployment_minimum_healthy_percent" {
  description = "Minimum healthy tasks during deployment (percentage of desired_count)."
  type        = number
  default     = 100
}

variable "deployment_maximum_percent" {
  description = "Maximum running tasks during deployment (percentage of desired_count)."
  type        = number
  default     = 200
}

variable "enable_execute_command" {
  description = "Enable ECS Exec for interactive debugging. Disable in production unless actively debugging."
  type        = bool
  default     = false
}

variable "propagate_tags" {
  description = "Propagate tags to tasks: 'SERVICE' or 'TASK_DEFINITION'."
  type        = string
  default     = "SERVICE"
}

variable "tags" {
  description = "Tags applied to all resources."
  type        = map(string)
  default     = {}
}
