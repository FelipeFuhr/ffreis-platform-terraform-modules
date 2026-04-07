# platform-terraform-modules

Opinionated, org-wide Terraform modules for the `ffreis` AWS platform.

---

## Why use these modules instead of native Terraform resources?

When you write a raw `aws_s3_bucket` resource, Terraform creates a bucket and nothing else. AWS ships the resource with almost everything disabled by default — no encryption, no public-access block, no TLS enforcement, no versioning, no logging. Every team that creates a bucket must remember to add seven extra resources. They won't — they never do, until an audit or an incident.

These modules flip that default. **Every security control that costs nothing to enable is on by default.** The caller opts out of a safe default only by explicitly passing a variable, making deliberate decisions visible in code review. The cost is writing slightly more Terraform; the benefit is that your entire org gets a consistent security baseline with no ongoing vigilance.

Concretely, the goals are:

| Problem with raw resources | What these modules do instead |
|---|---|
| Encryption is off by default | SSE is always enabled; pass a KMS key ARN for CMK |
| Public access is off by default | Public-access block is hardcoded on; not configurable |
| No audit trail by default | CloudTrail, VPC Flow Logs, CloudWatch retention are first-class options |
| Missing lifecycle controls | PITR on DynamoDB, snapshot retention on RDS/Redis, Object Lock on S3 |
| Misconfiguration is invisible | Variables are validated; invalid inputs fail at `terraform plan` |
| Repeating boilerplate across stacks | One module call vs. 7–15 resource blocks |

These modules are **not** a thin wrapper. They encode decisions: RDS always uses Secrets Manager for passwords; SQS always has a DLQ; Lambda always pre-creates its log group with retention set; Redis requires TLS by default. If a team wants something different they must explicitly override it and that override appears in code review.

---

## Module catalogue

### Cross-cutting

| Module | Purpose |
|---|---|
| [`tagging`](#tagging) | Required cost-allocation tag baseline — pass `module.tags.tags` to every other module |
| [`budget`](#budget) | AWS Budget with multi-threshold alerts (50 / 80 / 100% actual + 100% forecasted) |

### Foundations

| Module | Purpose |
|---|---|
| [`kms-key`](#kms-key) | KMS key + alias with annual rotation on by default |
| [`iam-role`](#iam-role) | Assumable IAM role with managed and inline policies |

### Networking

| Module | Purpose |
|---|---|
| [`vpc`](#vpc) | Multi-AZ VPC: public / private / database subnets, NAT, Flow Logs |
| [`vpc-endpoint`](#vpc-endpoint) | Gateway (S3, DynamoDB) and Interface endpoints — keep traffic off the internet |
| [`acm-certificate`](#acm-certificate) | ACM cert with auto Route 53 DNS validation and `create_before_destroy` |
| [`alb`](#alb) | ALB: HTTPS redirect, WAF association, target groups, listener rules |
| `cloudfront-website` | Static website origin bucket + CloudFront distribution with access logging, caller-supplied WAF, and optional CMK |

### Storage

| Module | Purpose |
|---|---|
| [`s3-bucket`](#s3-bucket) | S3 bucket: public-access block, SSE, TLS policy, versioning, Object Lock |
| [`dynamodb-table`](#dynamodb-table) | DynamoDB table: PITR, SSE, GSI, TTL, Streams |
| [`elasticache-redis`](#elasticache-redis) | ElastiCache Redis: TLS, at-rest encryption, Multi-AZ, snapshots |
| [`rds`](#rds) | RDS (Postgres/MySQL): managed password, enhanced monitoring, PI, deletion protection |
| [`ecr`](#ecr) | ECR: immutable tags, scan-on-push, lifecycle policy |
| [`secrets-manager`](#secrets-manager) | Secrets Manager: KMS encryption, auto-rotation |

### Messaging & events

| Module | Purpose |
|---|---|
| [`sqs`](#sqs) | SQS queue: SSE-KMS, DLQ, long-poll default |
| [`sns`](#sns) | SNS topic: SSE-KMS, subscriptions, filter policies |
| [`eventbridge-rule`](#eventbridge-rule) | EventBridge rule: schedule or pattern, multiple targets |
| [`kinesis-stream`](#kinesis-stream) | Kinesis Data Stream: ON_DEMAND mode, SSE-KMS, enhanced metrics |
| `ses-email-forwarder` | Inbound SES rule set, encrypted S3 mail store, and Lambda-based forwarding with optional CMKs |

### Compute

| Module | Purpose |
|---|---|
| [`lambda`](#lambda) | Lambda function: execution role, CW log group, X-Ray, VPC, DLQ |
| [`ecs-cluster`](#ecs-cluster) | ECS cluster: Container Insights, Fargate + Fargate Spot, ECS Exec |
| [`ecs-service`](#ecs-service) | ECS Fargate service: task definition, ALB integration, auto-scaling |
| [`step-functions`](#step-functions) | Step Functions state machine: X-Ray, CW Logs, IAM role |
| [`api-gateway-http`](#api-gateway-http) | HTTP API (v2): JWT authorizer, routes, CORS, throttling |

### Observability & compliance

| Module | Purpose |
|---|---|
| [`cloudwatch-log-group`](#cloudwatch-log-group) | CloudWatch log group: retention, KMS, skip-destroy |
| [`cloudwatch-alarms`](#cloudwatch-alarms) | Pre-canned alarms for Lambda, SQS, RDS, ALB, and ECS |
| [`cloudtrail`](#cloudtrail) | CloudTrail: multi-region, log validation, CW Logs, KMS |
| [`guardduty`](#guardduty) | GuardDuty detector: S3/EKS/malware protection, findings export |

### Identity & auth

| Module | Purpose |
|---|---|
| [`cognito-user-pool`](#cognito-user-pool) | Cognito: MFA, password policy, app clients, hosted UI |

### ML

| Module | Purpose |
|---|---|
| [`sagemaker-domain`](#sagemaker-domain) | SageMaker Studio domain: VPC-only mode, KMS, user profiles |

---

## Usage pattern

All modules follow the same three-file structure: `variables.tf`, `main.tf`, `outputs.tf`. Reference them via relative path (local development) or a versioned Git source tag in CI:

```hcl
# Local (monorepo / side-by-side repos)
module "my_bucket" {
  source = "../../platform-terraform-modules/modules/s3-bucket"
  bucket = "myapp-assets"
  tags   = local.common_tags
}

# Versioned (recommended for production stacks)
module "my_bucket" {
  source = "git::https://github.com/ffreis/platform-terraform-modules.git//modules/s3-bucket?ref=v1.2.0"
  bucket = "myapp-assets"
  tags   = local.common_tags
}
```

---

## Module reference

---

### `kms-key`

Creates a KMS Customer Managed Key with an alias.

**Why not `aws_kms_key` directly?**
Raw `aws_kms_key` defaults to no key rotation and no meaningful key policy, which means the root account has full access and nothing rotates. This module enables rotation by default and generates a least-privilege key policy.

```hcl
module "app_key" {
  source      = "../modules/kms-key"
  description = "Encryption key for myapp secrets and storage"
  alias       = "myapp/main"

  # Grant the application role permission to use the key.
  additional_principals = [module.app_role.arn]

  tags = local.common_tags
}
```

| Variable | Default | Notes |
|---|---|---|
| `alias` | — | Required. Written as `alias/<value>` |
| `description` | — | Required |
| `enable_key_rotation` | `true` | Annual rotation; disable only if you manage rotation yourself |
| `deletion_window_in_days` | `30` | 7–30 days before permanent deletion |
| `multi_region` | `false` | Multi-region primary key |
| `additional_principals` | `[]` | IAM ARNs granted Decrypt/GenerateDataKey |
| `policy` | `null` | Override entire key policy |

**Outputs:** `key_id`, `key_arn`, `alias_arn`, `alias_name`

---

### `iam-role`

Creates an IAM role with a trust policy, optional managed policy attachments, and inline policies.

**Why not `aws_iam_role` + `aws_iam_role_policy_attachment` directly?**
The raw resources are fine but every caller must wire three resources together and get the for_each pattern right. This module collapses them into a single `module` call.

```hcl
module "my_role" {
  source = "../modules/iam-role"
  name   = "myapp-worker"

  assume_role_policy = data.aws_iam_policy_document.trust.json

  managed_policy_arns = [
    "arn:aws:iam::aws:policy/AmazonSQSReadOnlyAccess",
  ]

  inline_policies = {
    write-to-s3 = data.aws_iam_policy_document.s3_write.json
  }

  tags = local.common_tags
}
```

| Variable | Default | Notes |
|---|---|---|
| `name` | — | Required |
| `assume_role_policy` | — | Required — JSON trust policy |
| `managed_policy_arns` | `[]` | List of managed policy ARNs to attach |
| `inline_policies` | `{}` | Map of name → JSON inline policy |
| `max_session_duration` | `3600` | 1 hour; extend for long-running CI jobs |
| `permissions_boundary` | `null` | ARN of a permissions boundary |

**Outputs:** `arn`, `name`, `id`

---

### `vpc`

Creates a multi-AZ VPC with public, private, and optionally isolated database subnets, NAT Gateways, and VPC Flow Logs.

**Why not raw VPC resources?**
A production-grade VPC requires ~20 resources: VPC, subnets, route tables, route table associations, Internet Gateway, NAT Gateways (and their Elastic IPs), DB subnet group, Flow Log, IAM role for Flow Log, and CloudWatch log group. Missing any one of them creates a security or reliability gap. This module gives you a correct, reviewable VPC with one `module` block.

```hcl
module "vpc" {
  source = "../modules/vpc"
  name   = "myapp-prod"
  cidr   = "10.0.0.0/16"

  azs = ["us-east-1a", "us-east-1b", "us-east-1c"]

  public_subnet_cidrs   = ["10.0.0.0/24", "10.0.1.0/24", "10.0.2.0/24"]
  private_subnet_cidrs  = ["10.0.10.0/23", "10.0.12.0/23", "10.0.14.0/23"]
  database_subnet_cidrs = ["10.0.20.0/24", "10.0.21.0/24", "10.0.22.0/24"]

  enable_nat_gateway = true
  single_nat_gateway = false  # One NAT per AZ for production HA

  enable_flow_logs         = true
  flow_logs_retention_days = 90
  flow_logs_kms_key_arn    = module.vpc_key.key_arn

  tags = local.common_tags
}
```

| Variable | Default | Notes |
|---|---|---|
| `cidr` | — | Required |
| `azs` | — | Required — must match subnet CIDR list lengths |
| `public_subnet_cidrs` | `[]` | One per AZ |
| `private_subnet_cidrs` | `[]` | One per AZ |
| `database_subnet_cidrs` | `[]` | Fully isolated — no default route |
| `enable_nat_gateway` | `true` | |
| `single_nat_gateway` | `false` | `true` = cheaper (non-prod); `false` = one per AZ (prod) |
| `enable_flow_logs` | `true` | Always enable in production |
| `flow_logs_retention_days` | `90` | |
| `create_database_subnet_group` | `true` | Creates `aws_db_subnet_group` for RDS |

**Outputs:** `vpc_id`, `vpc_cidr`, `public_subnet_ids`, `private_subnet_ids`, `database_subnet_ids`, `database_subnet_group_id`, `nat_gateway_ids`

---

### `s3-bucket`

Creates an S3 bucket with a hardcoded security baseline.

**Why not `aws_s3_bucket` directly?**
A raw `aws_s3_bucket` is an insecure bucket. It has no encryption, no public-access block, no TLS enforcement, no versioning. To reach the minimum acceptable configuration you need seven resource blocks. This module makes the safe configuration the default:

- Public-access block: **always on** — not a variable, not overridable
- Server-side encryption: **always on** (AES256 default, KMS optional)
- TLS-enforce bucket policy (`Deny s3:* where SecureTransport=false`): **always on**
- Versioning: on by default (pass `false` to disable)
- Object Lock (WORM): opt-in
- Intelligent-Tiering: opt-in (auto-moves objects to Archive after 90 days)

```hcl
module "artifacts" {
  source = "../modules/s3-bucket"
  bucket = "myapp-build-artifacts"

  versioning_enabled = true

  # KMS encryption instead of AES256:
  sse_algorithm     = "aws:kms"
  kms_master_key_id = module.app_key.key_arn

  lifecycle_rules = [{
    id                                 = "expire-old-artifacts"
    enabled                            = true
    noncurrent_version_expiration_days = 30
  }]

  tags = local.common_tags
}

# Compliance bucket with WORM:
module "audit_logs" {
  source = "../modules/s3-bucket"
  bucket = "myapp-audit-logs"

  object_lock_enabled = true
  object_lock_mode    = "COMPLIANCE"
  object_lock_years   = 7

  intelligent_tiering = true  # Move old logs to cheaper tiers automatically

  tags = local.common_tags
}
```

| Variable | Default | Notes |
|---|---|---|
| `bucket` | — | Required |
| `versioning_enabled` | `true` | |
| `sse_algorithm` | `"AES256"` | `"aws:kms"` for CMK |
| `kms_master_key_id` | `null` | Required when `sse_algorithm = "aws:kms"` |
| `lifecycle_rules` | `[]` | Expiry rules for current and noncurrent versions |
| `logging_target_bucket` | `""` | Enable access logging to another bucket |
| `object_lock_enabled` | `false` | WORM — cannot be disabled after creation |
| `object_lock_mode` | `"GOVERNANCE"` | `"COMPLIANCE"` for stricter retention |
| `intelligent_tiering` | `false` | Auto-archive after 90/180 days |
| `force_destroy` | `false` | Allow bucket deletion with objects inside |

**Outputs:** `id`, `arn`, `bucket_domain_name`, `bucket_regional_domain_name`, `hosted_zone_id`

---

### `dynamodb-table`

Creates a DynamoDB table with PITR and SSE always enabled.

**Why not `aws_dynamodb_table` directly?**
Raw DynamoDB tables have PITR disabled by default (35-day recovery window costs a small fee but is almost always worth it) and SSE defaults to the AWS-owned key rather than a customer-managed one. This module enables both unconditionally, provides a clean interface for GSIs, and handles attribute deduplication automatically.

```hcl
module "sessions" {
  source   = "../modules/dynamodb-table"
  name     = "myapp-sessions"
  hash_key = "SessionID"

  ttl_attribute = "ExpiresAt"

  tags = local.common_tags
}

module "orders" {
  source    = "../modules/dynamodb-table"
  name      = "myapp-orders"
  hash_key  = "CustomerID"
  range_key = "OrderID"

  global_secondary_indexes = [{
    name            = "StatusIndex"
    hash_key        = "Status"
    range_key       = "CreatedAt"
    projection_type = "ALL"
  }]

  attributes = [
    { name = "Status",    type = "S" },
    { name = "CreatedAt", type = "S" },
  ]

  stream_enabled   = true
  stream_view_type = "NEW_AND_OLD_IMAGES"

  kms_master_key_id = module.app_key.key_arn

  tags = local.common_tags
}
```

| Variable | Default | Notes |
|---|---|---|
| `name` | — | Required |
| `hash_key` | — | Required |
| `range_key` | `""` | Optional sort key |
| `billing_mode` | `"PAY_PER_REQUEST"` | |
| `global_secondary_indexes` | `[]` | |
| `ttl_attribute` | `""` | |
| `kms_master_key_id` | `null` | null = AWS-managed DynamoDB key (free) |
| `stream_enabled` | `false` | |
| `stream_view_type` | `"NEW_AND_OLD_IMAGES"` | |

**Outputs:** `id`, `arn`, `stream_arn`

---

### `sqs`

Creates an SQS queue with encryption, a Dead-Letter Queue, and sensible receive defaults.

**Why not `aws_sqs_queue` directly?**
Raw SQS queues ship with no encryption and no DLQ. Messages that fail processing disappear silently. Long-poll is off by default, meaning consumers waste money on empty receives. This module turns on SSE-KMS (using the AWS-managed SQS key by default), creates a paired DLQ with a 14-day retention window, and sets `receive_wait_time_seconds = 20` out of the box.

```hcl
module "job_queue" {
  source = "../modules/sqs"
  name   = "myapp-jobs"

  visibility_timeout_seconds = 300  # Match your Lambda timeout
  max_receive_count          = 3

  kms_master_key_id = "alias/aws/sqs"  # Or use a CMK

  tags = local.common_tags
}

# FIFO queue:
module "ordered_queue" {
  source     = "../modules/sqs"
  name       = "myapp-critical-jobs.fifo"
  fifo_queue = true
  content_based_deduplication = true

  tags = local.common_tags
}
```

| Variable | Default | Notes |
|---|---|---|
| `name` | — | Required. Must end in `.fifo` for FIFO queues |
| `fifo_queue` | `false` | |
| `visibility_timeout_seconds` | `30` | Should exceed consumer processing time |
| `receive_wait_time_seconds` | `20` | Long-poll; reduces empty-receive costs |
| `kms_master_key_id` | `"alias/aws/sqs"` | AWS-managed key; pass CMK ARN for stricter control |
| `create_dlq` | `true` | Strongly recommended to keep |
| `max_receive_count` | `5` | Deliveries before moving to DLQ |
| `dlq_message_retention_seconds` | `1209600` | 14 days |

**Outputs:** `queue_id`, `queue_arn`, `queue_name`, `dlq_arn`, `dlq_id`

---

### `sns`

Creates an SNS topic with SSE and optional subscriptions.

```hcl
module "alerts" {
  source = "../modules/sns"
  name   = "myapp-alerts"

  subscriptions = {
    ops-email = {
      protocol = "email"
      endpoint = "ops@example.com"
    }
    lambda-processor = {
      protocol = "lambda"
      endpoint = module.alert_processor.function_arn
      filter_policy = jsonencode({
        severity = ["critical", "high"]
      })
    }
  }

  tags = local.common_tags
}
```

| Variable | Default | Notes |
|---|---|---|
| `name` | — | Required |
| `kms_master_key_id` | `"alias/aws/sns"` | AWS-managed key; pass CMK ARN for stricter control |
| `subscriptions` | `{}` | Map of name → `{ protocol, endpoint, filter_policy, ... }` |
| `fifo_topic` | `false` | |

**Outputs:** `arn`, `name`, `subscription_arns`

---

### `lambda`

Creates a Lambda function with its execution role, CloudWatch log group (with retention), X-Ray tracing, and optional VPC attachment and DLQ.

**Why not `aws_lambda_function` directly?**
The two most common Lambda mistakes are: (1) letting AWS auto-create the log group, which means it has no retention policy and logs accumulate forever; (2) forgetting to attach the VPC execution policy when moving a function into a VPC. This module pre-creates the log group with configurable retention and automatically attaches `AWSLambdaVPCAccessExecutionRole` when VPC config is provided.

```hcl
module "api_handler" {
  source        = "../modules/lambda"
  function_name = "myapp-api-handler"
  runtime       = "python3.12"
  handler       = "index.handler"
  filename      = "${path.module}/dist/handler.zip"
  source_code_hash = filebase64sha256("${path.module}/dist/handler.zip")

  memory_size = 512
  timeout     = 30

  environment_variables = {
    TABLE_NAME = module.sessions.id
    QUEUE_URL  = module.job_queue.queue_id
  }

  # Attach to private subnets:
  vpc_subnet_ids         = module.vpc.private_subnet_ids
  vpc_security_group_ids = [aws_security_group.lambda.id]

  # Send failed async invocations to DLQ:
  dead_letter_target_arn = module.job_queue.dlq_arn

  log_retention_days = 30

  inline_policies = {
    read-table = data.aws_iam_policy_document.read_table.json
  }

  tags = local.common_tags
}

# Container image deployment:
module "ml_worker" {
  source        = "../modules/lambda"
  function_name = "myapp-ml-worker"
  image_uri     = "${module.ecr_repo.repository_url}:latest"
  handler       = ""     # Not used for Image package type
  runtime       = ""     # Not used for Image package type
  architectures = ["arm64"]
  memory_size   = 3008
  timeout       = 900

  tags = local.common_tags
}
```

| Variable | Default | Notes |
|---|---|---|
| `function_name` | — | Required |
| `runtime` | — | Required for Zip; empty for Image |
| `handler` | — | Required for Zip; empty for Image |
| `filename` | `null` | Path to zip package |
| `image_uri` | `null` | ECR image URI (mutually exclusive with `filename`) |
| `architectures` | `["arm64"]` | ARM64 is cheaper and faster for most workloads |
| `memory_size` | `128` | MB |
| `timeout` | `30` | Seconds |
| `tracing_mode` | `"Active"` | X-Ray; `"PassThrough"` to disable |
| `log_retention_days` | `30` | CloudWatch retention |
| `vpc_subnet_ids` | `[]` | VPC attachment — VPC policy attached automatically |
| `dead_letter_target_arn` | `null` | SQS or SNS ARN |
| `event_source_mappings` | `{}` | SQS, DynamoDB Streams, Kinesis triggers |

**Outputs:** `function_arn`, `function_name`, `invoke_arn`, `execution_role_arn`, `log_group_name`

---

### `eventbridge-rule`

Creates an EventBridge rule with one or more targets.

```hcl
# Scheduled rule (cron):
module "daily_cleanup" {
  source = "../modules/eventbridge-rule"
  name   = "myapp-daily-cleanup"

  schedule_expression = "cron(0 3 * * ? *)"  # 03:00 UTC daily

  targets = {
    cleanup-lambda = {
      arn = module.cleanup_fn.function_arn
      input = jsonencode({ action = "cleanup", dry_run = false })
      retry_policy = {
        maximum_event_age_in_seconds = 3600
        maximum_retry_attempts       = 2
      }
    }
  }

  tags = local.common_tags
}

# Event-pattern rule:
module "on_order_created" {
  source = "../modules/eventbridge-rule"
  name   = "myapp-on-order-created"

  event_pattern = jsonencode({
    source      = ["myapp.orders"]
    detail-type = ["OrderCreated"]
  })

  targets = {
    notify-sns = { arn = module.alerts.arn }
    process-sqs = {
      arn                  = module.job_queue.queue_arn
      sqs_message_group_id = "orders"
    }
  }

  tags = local.common_tags
}
```

| Variable | Default | Notes |
|---|---|---|
| `name` | — | Required |
| `schedule_expression` | `null` | Cron or rate expression |
| `event_pattern` | `null` | JSON pattern; mutually exclusive with `schedule_expression` |
| `state` | `"ENABLED"` | |
| `targets` | `{}` | Map of target name → `{ arn, input, dead_letter_arn, retry_policy, ... }` |

**Outputs:** `rule_arn`, `rule_name`

---

### `cloudwatch-log-group`

Creates a CloudWatch log group with configurable retention and optional KMS encryption.

**Why not `aws_cloudwatch_log_group` directly?**
The native resource is thin but two defaults are dangerous: retention defaults to `0` (never expire), which causes unbounded storage costs; and there is no encryption by default. This module requires you to be explicit about retention and makes KMS encryption easy to add.

```hcl
module "app_logs" {
  source            = "../modules/cloudwatch-log-group"
  name              = "/myapp/application"
  retention_in_days = 30
  kms_key_arn       = module.app_key.key_arn
  tags              = local.common_tags
}

# Audit log group that survives terraform destroy:
module "audit_logs" {
  source            = "../modules/cloudwatch-log-group"
  name              = "/myapp/audit"
  retention_in_days = 365
  skip_destroy      = true
  tags              = local.common_tags
}
```

| Variable | Default | Notes |
|---|---|---|
| `name` | — | Required |
| `retention_in_days` | `90` | Must be a value accepted by CloudWatch (validated) |
| `kms_key_arn` | `null` | |
| `skip_destroy` | `false` | Preserve the log group on `terraform destroy` |

**Outputs:** `name`, `arn`

---

### `cloudtrail`

Creates a CloudTrail trail with log file validation, optional multi-region coverage, and optional CloudWatch Logs streaming.

**Why not `aws_cloudtrail` directly?**
CloudTrail has no default destination and log file validation is off by default. Without validation, an attacker who gains S3 write access can delete or alter log files without detection. This module enables validation unconditionally and wires up the CloudWatch Logs destination, including the IAM role and log group, in one call.

```hcl
module "audit_trail" {
  source         = "../modules/cloudtrail"
  name           = "myapp-audit"
  s3_bucket_name = module.audit_bucket.id

  kms_key_arn = module.audit_key.key_arn

  is_multi_region_trail          = true
  include_global_service_events  = true
  enable_cloudwatch_logs         = true
  cloudwatch_logs_retention_days = 365

  # Capture S3 data events for sensitive buckets:
  event_selectors = [{
    read_write_type           = "All"
    include_management_events = true
    data_resources = [{
      type   = "AWS::S3::Object"
      values = ["${module.sensitive_bucket.arn}/"]
    }]
  }]

  tags = local.common_tags
}
```

| Variable | Default | Notes |
|---|---|---|
| `name` | — | Required |
| `s3_bucket_name` | — | Required — bucket must exist and have the CloudTrail bucket policy |
| `is_multi_region_trail` | `true` | Recommended |
| `enable_log_file_validation` | `true` | Always keep this on |
| `kms_key_arn` | `null` | Strongly recommended for production |
| `enable_cloudwatch_logs` | `true` | |
| `cloudwatch_logs_retention_days` | `365` | |

**Outputs:** `trail_arn`, `trail_name`, `cloudwatch_log_group_arn`

---

### `rds`

Creates an RDS instance (Postgres or MySQL) with sensible production defaults: Secrets Manager-managed password, storage autoscaling, Enhanced Monitoring, Performance Insights, and deletion protection.

**Why not `aws_db_instance` directly?**
The raw resource defaults are not production-ready: unencrypted storage, no backups (`backup_retention_period = 0`), no deletion protection, and the master password in plaintext state. Every team forgets at least one of these. This module inverts the defaults — deletion protection and backups are on, RDS manages the password in Secrets Manager, and Enhanced Monitoring ships logs to the existing IAM role it creates.

```hcl
module "app_db" {
  source         = "../modules/rds"
  identifier     = "myapp-prod"
  engine         = "postgres"
  engine_version = "16.3"
  instance_class = "db.t4g.medium"

  db_name  = "myapp"
  username = "myapp_admin"
  # manage_master_user_password = true (default) — no password variable needed

  db_subnet_group_name   = module.vpc.database_subnet_group_id
  vpc_security_group_ids = [aws_security_group.rds.id]

  storage_encrypted = true
  kms_key_id        = module.db_key.key_arn

  multi_az                = true
  backup_retention_period = 14

  enabled_cloudwatch_logs_exports = ["postgresql", "upgrade"]

  performance_insights_enabled    = true
  performance_insights_kms_key_id = module.db_key.key_arn

  tags = local.common_tags
}

# Read the managed password ARN for application config:
output "db_password_secret_arn" {
  value = module.app_db.master_user_secret_arn
}
```

| Variable | Default | Notes |
|---|---|---|
| `identifier` | — | Required |
| `engine` | `"postgres"` | `"postgres"` or `"mysql"` |
| `engine_version` | — | Required |
| `instance_class` | — | Required |
| `username` | — | Required |
| `manage_master_user_password` | `true` | RDS stores the password in Secrets Manager |
| `deletion_protection` | `true` | Keep on for production |
| `backup_retention_period` | `7` | Days |
| `multi_az` | `false` | Enable for production |
| `monitoring_interval` | `60` | Enhanced Monitoring; 0 to disable |
| `performance_insights_enabled` | `true` | |
| `storage_encrypted` | `true` | |

**Outputs:** `db_instance_id`, `db_instance_endpoint`, `db_instance_address`, `db_instance_port`, `master_user_secret_arn`

---

### `ecr`

Creates an ECR repository with immutable tags, scan-on-push, and an automatic lifecycle policy.

**Why not `aws_ecr_repository` directly?**
By default ECR tags are mutable (images can be overwritten), vulnerability scanning is off, and no lifecycle policy exists (images accumulate indefinitely). This module flips all three defaults and generates a lifecycle policy that expires untagged images after 14 days and retains only the 30 most recent tagged images.

```hcl
module "api_image" {
  source = "../modules/ecr"
  name   = "myapp/api"

  image_tag_mutability = "IMMUTABLE"    # default
  scan_on_push         = true           # default
  keep_image_count     = 20
  untagged_image_expiry_days = 7

  # Cross-account pull access:
  repository_policy = data.aws_iam_policy_document.ecr_pull.json

  tags = local.common_tags
}
```

| Variable | Default | Notes |
|---|---|---|
| `name` | — | Required |
| `image_tag_mutability` | `"IMMUTABLE"` | Prevents tag overwriting |
| `scan_on_push` | `true` | |
| `encryption_type` | `"AES256"` | `"KMS"` for CMK |
| `keep_image_count` | `30` | Retain N most recent tagged images |
| `untagged_image_expiry_days` | `14` | |
| `force_delete` | `false` | Allow deletion with images |

**Outputs:** `repository_url`, `repository_arn`, `repository_name`, `registry_id`

---

### `elasticache-redis`

Creates an ElastiCache Redis replication group with TLS, at-rest encryption, Multi-AZ, and automated snapshots.

**Why not `aws_elasticache_replication_group` directly?**
ElastiCache defaults to plaintext connections (`transit_encryption_enabled = false`) and no at-rest encryption. This module requires TLS in transit and enables at-rest encryption by default.

```hcl
module "cache" {
  source      = "../modules/elasticache-redis"
  cluster_id  = "myapp-cache"
  description = "Session and rate-limit cache for myapp"
  node_type   = "cache.t4g.small"

  subnet_group_name  = aws_elasticache_subnet_group.main.name
  security_group_ids = [aws_security_group.redis.id]

  num_cache_clusters     = 2  # Primary + one replica
  automatic_failover_enabled = true
  multi_az_enabled           = true

  auth_token = var.redis_auth_token  # From Secrets Manager

  snapshot_retention_limit = 7

  tags = local.common_tags
}
```

| Variable | Default | Notes |
|---|---|---|
| `cluster_id` | — | Required |
| `node_type` | — | Required |
| `subnet_group_name` | — | Required |
| `security_group_ids` | — | Required |
| `engine_version` | `"7.1"` | |
| `num_cache_clusters` | `2` | 1 = no replica |
| `transit_encryption_enabled` | `true` | TLS; keep on |
| `transit_encryption_mode` | `"required"` | `"preferred"` allows plaintext fallback |
| `at_rest_encryption_enabled` | `true` | |
| `snapshot_retention_limit` | `7` | 0 = disabled |

**Outputs:** `primary_endpoint_address`, `reader_endpoint_address`, `port`, `arn`

---

### `secrets-manager`

Creates a Secrets Manager secret with optional KMS encryption and auto-rotation.

```hcl
# Store a credential:
module "db_creds" {
  source     = "../modules/secrets-manager"
  name       = "/myapp/prod/db-credentials"
  kms_key_id = module.app_key.key_arn

  secret_string = jsonencode({
    username = "myapp_admin"
    password = var.db_password
  })

  tags = local.common_tags
}

# With auto-rotation:
module "api_key" {
  source              = "../modules/secrets-manager"
  name                = "/myapp/prod/api-key"
  kms_key_id          = module.app_key.key_arn
  enable_rotation     = true
  rotation_lambda_arn = module.rotation_fn.function_arn
  rotation_automatically_after_days = 30

  tags = local.common_tags
}
```

| Variable | Default | Notes |
|---|---|---|
| `name` | — | Required |
| `kms_key_id` | `null` | Strongly recommended |
| `secret_string` | `null` | Plain text or JSON value |
| `recovery_window_in_days` | `30` | 0 = immediate delete (use in tests only) |
| `enable_rotation` | `false` | |
| `rotation_lambda_arn` | `null` | Required when `enable_rotation = true` |

**Outputs:** `secret_arn`, `secret_id`, `secret_name`, `version_id`

---

### `sagemaker-domain`

Creates a SageMaker Studio domain in VPC-only mode with optional user profiles.

```hcl
module "studio" {
  source      = "../modules/sagemaker-domain"
  domain_name = "myteam-studio"
  vpc_id      = module.vpc.vpc_id
  subnet_ids  = module.vpc.private_subnet_ids

  app_network_access_type = "VpcOnly"  # default — no direct internet access
  kms_key_id = module.studio_key.key_arn

  default_user_settings = {
    execution_role  = module.sagemaker_execution_role.arn
    security_groups = [aws_security_group.sagemaker.id]
  }

  user_profiles = {
    alice = { execution_role = module.alice_role.arn }
    bob   = {}  # Inherits domain default
  }

  tags = local.common_tags
}
```

| Variable | Default | Notes |
|---|---|---|
| `domain_name` | — | Required |
| `vpc_id` | — | Required |
| `subnet_ids` | — | Required — private subnets recommended |
| `app_network_access_type` | `"VpcOnly"` | `"PublicInternetOnly"` opens internet access from kernels |
| `auth_mode` | `"IAM"` | `"SSO"` for IAM Identity Center integration |
| `default_user_settings.execution_role` | — | Required |
| `user_profiles` | `{}` | Map of name → overrides |

**Outputs:** `domain_id`, `domain_arn`, `home_efs_file_system_id`, `url`, `user_profile_arns`

---

## Security baseline summary

Every module in this library applies the following controls by default, regardless of caller input:

| Control | Modules |
|---|---|
| Encryption at rest | All storage modules (S3, DynamoDB, RDS, Redis, ECR, Secrets Manager, SQS, SNS) |
| Encryption in transit | RDS (TLS cert required), Redis (TLS required), S3 (TLS-enforce policy) |
| Public access blocked | S3 (hardcoded), RDS (`publicly_accessible = false`) |
| Automated backups / PITR | DynamoDB (PITR), RDS (7-day retention), Redis (7-day snapshots) |
| Deletion protection | RDS, DynamoDB (enforce via `lifecycle { prevent_destroy }` in calling stacks) |
| Log retention | Lambda (30 days), VPC Flow Logs (90 days), CloudTrail CW Logs (365 days) |
| IAM least privilege | Lambda creates a minimal execution role; CloudTrail and Flow Logs create write-only roles |
| Key rotation | KMS keys rotate annually by default |

---

### `tagging`

Produces a validated tag map that every other module accepts as `tags`. Using this module instead of a hand-crafted `locals` block ensures no resource is ever created without the tags needed for billing attribution, team ownership, and data classification.

**Why this matters for billing**
AWS Cost Explorer and cost allocation reports only work on resources that have cost-allocation tags activated. If a single resource is missing `CostCenter` or `Team`, its spend is unattributable. This module makes those tags required at the Terraform level — a `terraform plan` fails if they are missing.

```hcl
module "tags" {
  source = "../modules/tagging"

  workspace           = terraform.workspace   # "management" | "ml" | "db" | "prod"
  service             = "myapp-api"
  team                = "backend"
  cost_center         = "CC-1042"
  repository          = "github.com/ffreis/myapp"
  data_classification = "confidential"
}

# Pass to every other module:
module "my_bucket" {
  source = "../modules/s3-bucket"
  bucket = "myapp-data"
  tags   = module.tags.tags   # <── all required tags flow through
}
```

**Required tags (enforced):**

| Tag | Purpose |
|---|---|
| `Workspace` | Terraform workspace / environment |
| `Service` | Application or service name |
| `Team` | Owning team — used in team-level billing splits |
| `CostCenter` | Cost center code for finance allocation |
| `ManagedBy` | `terraform` or `manual` |
| `DataClassification` | `public` / `internal` / `confidential` / `restricted` |

**Outputs:** `tags` (complete map), `workspace`, `service`

---

### `budget`

Creates an AWS Budget with four default alert thresholds: 50%, 80%, 100% actual spend, and 100% forecasted spend. Works at account level or scoped to specific services via `cost_filters`.

```hcl
module "monthly_budget" {
  source       = "../modules/budget"
  name         = "ffreis-monthly"
  limit_amount = 500  # USD

  alert_email_addresses = ["ops@example.com"]
  alert_sns_arns        = [module.alerts.arn]

  tags = module.tags.tags
}

# Per-workspace budget:
module "ml_budget" {
  source       = "../modules/budget"
  name         = "ffreis-ml-workspace"
  limit_amount = 2000

  cost_filters = {
    TagKeyValue = ["user:Workspace$ml"]
  }

  alert_email_addresses = ["ml-team@example.com"]
  tags = module.tags.tags
}
```

**Outputs:** `id`, `name`

---

### `vpc-endpoint`

Creates Gateway endpoints (S3, DynamoDB — free) and Interface endpoints (SSM, ECR, Secrets Manager, etc. — billed per ENI-hour) to keep VPC traffic off the public internet.

```hcl
module "endpoints" {
  source = "../modules/vpc-endpoint"
  vpc_id = module.vpc.vpc_id
  region = "us-east-1"

  # Free — route-table based
  gateway_endpoints = {
    s3       = "s3"
    dynamodb = "dynamodb"
  }
  gateway_route_table_ids = concat(
    module.vpc.private_route_table_ids,
    [module.vpc.database_route_table_id],
  )

  # Billed per AZ — use selectively
  interface_endpoints = {
    ssm            = "ssm"
    ssmmessages    = "ssmmessages"
    secretsmanager = "secretsmanager"
    ecr-api        = "ecr.api"
    ecr-dkr        = "ecr.dkr"
    logs           = "logs"
    kms            = "kms"
  }
  interface_subnet_ids         = module.vpc.private_subnet_ids
  interface_security_group_ids = [aws_security_group.endpoints.id]

  tags = module.tags.tags
}
```

**Outputs:** `gateway_endpoint_ids`, `interface_endpoint_ids`, `interface_endpoint_dns`

---

### `acm-certificate`

Creates an ACM certificate and automatically creates Route 53 DNS validation records. Blocks until the certificate is issued.

```hcl
module "cert" {
  source          = "../modules/acm-certificate"
  domain_name     = "myapp.example.com"
  subject_alternative_names = ["*.myapp.example.com"]
  hosted_zone_id  = data.aws_route53_zone.main.zone_id
  tags            = module.tags.tags
}
```

**Outputs:** `arn`, `domain_name`, `status`

---

### `alb`

Creates an Application Load Balancer with HTTPS redirect, deletion protection, optional WAF, optional access logs, target groups, and path/host listener rules.

```hcl
module "alb" {
  source             = "../modules/alb"
  name               = "myapp-prod"
  vpc_id             = module.vpc.vpc_id
  subnet_ids         = module.vpc.public_subnet_ids
  security_group_ids = [aws_security_group.alb.id]
  certificate_arn    = module.cert.arn

  target_groups = {
    api = {
      port        = 8080
      target_type = "ip"
      health_check = { path = "/health" }
    }
  }

  https_listener_rules = {
    api = {
      target_group = "api"
      priority     = 10
      conditions   = [{ field = "path-pattern", values = ["/api/*"] }]
    }
  }

  access_logs_bucket = module.access_logs_bucket.id
  waf_acl_arn        = module.waf.arn

  tags = module.tags.tags
}
```

**Outputs:** `arn`, `dns_name`, `zone_id`, `https_listener_arn`, `target_group_arns`

---

### `ecs-cluster`

Creates an ECS cluster with Container Insights and Fargate / Fargate Spot capacity providers.

```hcl
module "cluster" {
  source = "../modules/ecs-cluster"
  name   = "myapp-prod"
  tags   = module.tags.tags
}
```

**Outputs:** `id`, `arn`, `name`

---

### `ecs-service`

Creates a Fargate service with task definition, IAM roles, ALB integration, circuit breaker, and CPU/memory auto-scaling.

```hcl
module "api_service" {
  source      = "../modules/ecs-service"
  name        = "myapp-api"
  cluster_arn = module.cluster.arn

  cpu    = 512
  memory = 1024

  container_definitions = jsonencode([{
    name      = "api"
    image     = "${module.ecr.repository_url}:${var.image_tag}"
    portMappings = [{ containerPort = 8080, protocol = "tcp" }]
    environment = [{ name = "ENV", value = "prod" }]
    logConfiguration = {
      logDriver = "awslogs"
      options = {
        awslogs-group         = "/ecs/myapp-api"
        awslogs-region        = "us-east-1"
        awslogs-stream-prefix = "api"
      }
    }
  }])

  subnet_ids         = module.vpc.private_subnet_ids
  security_group_ids = [aws_security_group.service.id]

  load_balancers = [{
    target_group_arn = module.alb.target_group_arns["api"]
    container_name   = "api"
    container_port   = 8080
  }]

  autoscaling_min_capacity = 2
  autoscaling_max_capacity = 20
  autoscaling_cpu_target   = 70

  tags = module.tags.tags
}
```

**Outputs:** `service_name`, `task_definition_arn`, `task_role_arn`, `execution_role_arn`

---

### `cloudwatch-alarms`

Creates pre-canned CloudWatch alarms for Lambda, SQS, RDS, ALB, and ECS. Wire a single SNS topic to all alarms and call this module once per workspace.

```hcl
module "alarms" {
  source        = "../modules/cloudwatch-alarms"
  name_prefix   = "myapp-prod"
  alarm_actions = [module.alerts.arn]
  ok_actions    = [module.alerts.arn]

  lambda_alarms = {
    "myapp-api-handler" = {
      error_rate_threshold   = 5
      throttle_threshold     = 10
      duration_p99_threshold = 25000
    }
  }

  sqs_alarms = {
    "myapp-jobs" = {
      dlq_depth_threshold   = 1
      age_threshold_seconds = 300
    }
  }

  rds_alarms = {
    "myapp-prod" = {
      cpu_threshold      = 80
      free_storage_bytes = 10737418240  # 10 GiB
    }
  }

  ecs_alarms = {
    "myapp-prod/myapp-api" = {
      cpu_threshold    = 80
      memory_threshold = 85
    }
  }

  tags = module.tags.tags
}
```

**Outputs:** `lambda_alarm_arns`, `sqs_alarm_arns`, `rds_alarm_arns`, `alb_alarm_arns`, `ecs_alarm_arns`

---

### `guardduty`

Enables GuardDuty with S3, EKS, and malware protection options. One call per account/region.

```hcl
module "guardduty" {
  source                      = "../modules/guardduty"
  enable_s3_protection        = true
  finding_publishing_frequency = "ONE_HOUR"
  findings_s3_bucket          = module.audit_bucket.id
  findings_kms_key_arn        = module.audit_key.key_arn
  tags                        = module.tags.tags
}
```

**Outputs:** `detector_id`, `detector_arn`

---

### `api-gateway-http`

Creates an HTTP API (v2) with optional JWT authorizer (Cognito), CORS, route-level integration, and throttling.

```hcl
module "api" {
  source = "../modules/api-gateway-http"
  name   = "myapp-api"

  jwt_authorizer = {
    name     = "cognito"
    issuer   = "https://cognito-idp.us-east-1.amazonaws.com/${module.user_pool.id}"
    audience = [module.user_pool.client_ids["web-app"]]
  }

  cors_configuration = {
    allow_origins = ["https://myapp.example.com"]
    allow_methods = ["GET", "POST", "PUT", "DELETE"]
  }

  routes = {
    "GET /users"  = { integration_uri = module.api_fn.invoke_arn, authorizer = "jwt" }
    "POST /users" = { integration_uri = module.api_fn.invoke_arn, authorizer = "jwt" }
    "GET /health" = { integration_uri = module.api_fn.invoke_arn }  # public
  }

  access_log_arn = module.api_logs.arn
  tags           = module.tags.tags
}
```

**Outputs:** `api_id`, `api_endpoint`, `execution_arn`

---

### `cognito-user-pool`

Creates a Cognito user pool with enforced MFA (TOTP by default), advanced security, password policy, app clients, and a hosted UI domain.

```hcl
module "user_pool" {
  source = "../modules/cognito-user-pool"
  name   = "myapp-users"

  mfa_configuration      = "OPTIONAL"
  advanced_security_mode = "ENFORCED"

  app_clients = {
    web-app = {
      allowed_oauth_flows  = ["code"]
      callback_urls        = ["https://myapp.example.com/callback"]
      logout_urls          = ["https://myapp.example.com/logout"]
      access_token_validity = 60
    }
  }

  tags = module.tags.tags
}
```

**Outputs:** `id`, `arn`, `endpoint`, `client_ids`, `domain`

---

### `kinesis-stream`

Creates a Kinesis Data Stream in ON_DEMAND mode with SSE-KMS and all enhanced shard-level metrics enabled.

```hcl
module "events" {
  source           = "../modules/kinesis-stream"
  name             = "myapp-events"
  stream_mode      = "ON_DEMAND"
  retention_period = 168  # 7 days
  kms_key_id       = module.app_key.key_arn
  tags             = module.tags.tags
}
```

**Outputs:** `name`, `arn`

---

### `step-functions`

Creates a Step Functions state machine with X-Ray tracing, CloudWatch execution logs, and an auto-created IAM role.

```hcl
module "order_workflow" {
  source     = "../modules/step-functions"
  name       = "myapp-order-workflow"
  type       = "STANDARD"
  definition = file("${path.module}/statemachine/order.asl.json")

  log_level                  = "ERROR"
  log_include_execution_data = false  # don't log sensitive order data

  role_inline_policies = {
    invoke-lambdas = data.aws_iam_policy_document.sfn_invoke.json
  }

  tags = module.tags.tags
}
```

**Outputs:** `arn`, `name`, `role_arn`, `log_group_arn`

---

## Workspace design and persona-based IAM

### Workspace layout

Split Terraform state by concern, not just by environment. A workload that spans concerns (ML + DB) should still live in separate stacks so blast radius is minimal.

```
stacks/
  management/          # GuardDuty, CloudTrail, Budgets, org-level IAM, tagging policies
  networking/          # VPC, subnets, VPC endpoints, Route 53, ACM certs
  db/                  # RDS, ElastiCache, DynamoDB, Secrets Manager, DB subnet groups
  ml/                  # SageMaker domain, ECR for ML images, S3 model artifacts, Kinesis
  platform/            # ECS clusters, ALBs, shared SQS/SNS topics, EventBridge bus
  app-<name>/          # One stack per application: Lambda/ECS service, API GW, Cognito
```

Each stack:
- uses `module "tags" { workspace = "db" ... }` so every resource is labelled
- has its own S3 state bucket + DynamoDB lock table
- has its own budget (scoped with `TagKeyValue = ["user:Workspace$db"]`)
- is deployed by a dedicated OIDC role with minimum permissions for that concern

### Persona-based IAM

The idea is that a **persona** is a named bundle of permissions that maps to a job function. Personas are implemented as IAM roles composed from managed policies and optionally scoped with a permissions boundary.

```
personas/
  db-admin        → RDS full access, Secrets Manager read, CloudWatch read
                    DENY: SageMaker, ECS, Lambda, ECR
  ml-engineer     → SageMaker full, S3 model-artifacts read/write, ECR pull
                    DENY: RDS, ElastiCache, Secrets Manager
  platform-eng    → ECS, Lambda, API GW, SQS, SNS, EventBridge, CloudWatch
                    DENY: RDS, SageMaker
  read-only       → * read-only, DENY: all write actions
  auditor         → CloudTrail, Config, Security Hub, GuardDuty read-only
```

Implement personas as `iam-role` module calls with a `permissions_boundary` pointing to a boundary policy that caps the maximum permissions of any role in the org. The trust policy uses OIDC (GitHub Actions, SSO, or the identity provider) rather than IAM users.

```hcl
# modules/persona-db-admin/main.tf
module "role" {
  source = "../../modules/iam-role"
  name   = "persona-db-admin-${var.workspace}"

  assume_role_policy   = var.assume_role_policy   # OIDC or SSO trust
  permissions_boundary = var.permissions_boundary_arn

  managed_policy_arns = [
    "arn:aws:iam::aws:policy/AmazonRDSFullAccess",
    "arn:aws:iam::aws:policy/SecretsManagerReadWrite",
    "arn:aws:iam::aws:policy/CloudWatchReadOnlyAccess",
  ]

  inline_policies = {
    # Explicit deny makes the boundary visible in the role itself.
    deny-non-db-services = jsonencode({
      Version = "2012-10-17"
      Statement = [{
        Effect   = "Deny"
        Action   = ["sagemaker:*", "ecs:*", "lambda:*", "ecr:*"]
        Resource = "*"
      }]
    })
  }
}
```

Each persona is a separate Terraform module so it can be independently versioned and audited.

---

## Testing modules

### What the industry uses

| Tool | What it does | When to use |
|---|---|---|
| `terraform validate` | Syntax + type checking | Every PR, in pre-commit |
| `terraform fmt -check` | Format check | Every PR, in pre-commit |
| `tflint` | Linting: deprecated syntax, missing vars, provider-specific rules | Every PR |
| `checkov` / `tfsec` | Static security analysis: finds misconfigurations before `apply` | Every PR |
| **Terratest** (Go) | Provisions real infrastructure, runs assertions, tears down | Integration tests |
| `terraform-compliance` | BDD-style policy assertions against plan JSON | Policy-as-code |
| `conftest` / OPA | Rego policies evaluated against plan JSON | Policy-as-code |
| `tfmock` / `localstack` | Fake AWS locally — limited coverage | Unit-ish tests |

### The Terratest pattern (the one you mentioned)

Terratest is a Go library by Gruntwork that provisions actual AWS resources in a test account, runs assertions, then destroys everything. It's the most thorough approach because it catches IAM permission errors, eventual-consistency races, and output correctness — things static analysis cannot.

Structure for this repo:

```
test/
  s3_bucket_test.go
  cloudtrail_test.go
  ecs_cluster_test.go
  cloudfront_website_validate_test.go
  ses_email_forwarder_validate_test.go
  helpers_test.go    # shared setup: region, prefix, tag baseline
```

### Current coverage in this repo

| Coverage mode | Modules |
|---|---|
| Live Terratest apply/destroy | `s3-bucket`, `dynamodb-table`, `iam-role`, `kms-key`, `sns`, `sqs`, `ecr`, `ecs-cluster`, `cloudtrail` |
| Validate-only fixture tests | `cloudfront-website`, `ses-email-forwarder` |

The regular CI path runs `make test-ci`. Live AWS tests execute when credentials are present and skip cleanly otherwise; the validate-only fixture tests always run and catch module interface regressions for the higher-friction modules.

Example test for the `s3-bucket` module:

```go
package test

import (
    "testing"

    "github.com/gruntwork-io/terratest/modules/aws"
    "github.com/gruntwork-io/terratest/modules/terraform"
    "github.com/stretchr/testify/assert"
    "github.com/stretchr/testify/require"
)

func TestS3BucketModule(t *testing.T) {
    t.Parallel()

    uniqueID := terraform.UniqueID()
    bucketName := "test-s3-module-" + uniqueID

    opts := &terraform.Options{
        TerraformDir: "../modules/s3-bucket",
        Vars: map[string]interface{}{
            "bucket": bucketName,
            "tags":   map[string]string{"Workspace": "test", "Service": "terratest"},
        },
    }

    defer terraform.Destroy(t, opts)
    terraform.InitAndApply(t, opts)

    // Verify public-access block is enforced.
    region := "us-east-1"
    block := aws.GetS3BucketPublicAccessBlock(t, region, bucketName)
    assert.True(t, block.BlockPublicAcls)
    assert.True(t, block.BlockPublicPolicy)
    assert.True(t, block.IgnorePublicAcls)
    assert.True(t, block.RestrictPublicBuckets)

    // Verify SSE is enabled.
    encryption := aws.GetS3BucketEncryption(t, region, bucketName)
    require.Len(t, encryption.Rules, 1)
    assert.NotNil(t, encryption.Rules[0].ApplyServerSideEncryptionByDefault)
}
```

### CI pipeline for modules

```yaml
# .github/workflows/terraform.yml
name: Terraform modules CI

on:
  push:
    branches: [main]
  pull_request:

jobs:
  validate:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v4
      - uses: hashicorp/setup-terraform@v3
        with: { terraform_version: "1.9.x" }

      - name: fmt check
        run: terraform fmt -check -recursive modules/

      - name: validate each module
        run: |
          for dir in modules/*/; do
            echo "==> $dir"
            (cd "$dir" && terraform init -backend=false && terraform validate)
          done

  lint:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v4
      - uses: terraform-linters/setup-tflint@v4
      - run: tflint --recursive

  security:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v4
      - uses: bridgecrewio/checkov-action@v12
        with:
          directory: modules/
          framework: terraform
          soft_fail: false

  integration:
    runs-on: ubuntu-latest
    needs: [validate, lint, security]
    if: github.ref == 'refs/heads/main'   # Only run on merge; costs real money
    permissions:
      id-token: write
      contents: read
    steps:
      - uses: actions/checkout@v4
      - uses: aws-actions/configure-aws-credentials@v4
        with:
          role-to-assume: ${{ secrets.TEST_ROLE_ARN }}
          aws-region: us-east-1
      - uses: actions/setup-go@v5
        with: { go-version: "1.24" }
      - name: Run Terratest
        run: go test ./test/... -v -timeout 30m
```

### Static-only path (no test AWS account needed)

If you don't have a dedicated test account yet, this gives you meaningful coverage cheaply:

1. **`terraform validate`** — catches type errors and missing required variables
2. **`tflint`** with the AWS ruleset — catches deprecated resources, unused variables, wrong instance types
3. **`checkov`** — fails on hardcoded credentials, open security groups, missing encryption, public S3 buckets
4. **`terraform plan` against a mock** — use `tfmock` or LocalStack for a subset of resources

Add all four to the CI pipeline; add Terratest later when you have a test account.

---

## Repository structure

```
modules/
  acm-certificate/
  alb/
  api-gateway-http/
  budget/
  cloudtrail/
  cloudwatch-alarms/
  cloudwatch-log-group/
  cognito-user-pool/
  dynamodb-table/
  ecr/
  ecs-cluster/
  ecs-service/
  elasticache-redis/
  eventbridge-rule/
  guardduty/
  iam-role/
  kinesis-stream/
  kms-key/
  lambda/
  rds/
  s3-bucket/
  sagemaker-domain/
  secrets-manager/
  sns/
  sqs/
  step-functions/
  tagging/
  vpc/
  vpc-endpoint/
test/
  helpers_test.go
  s3_bucket_test.go
  vpc_test.go
  ...
```

Each module contains exactly: `variables.tf`, `main.tf`, `outputs.tf`.

---

## Contributing

1. All security controls that are free must be on by default.
2. Callers opt **out** of safe defaults, not in — overrides are visible in diffs.
3. Add `validation` blocks for every variable that has a bounded set of valid values.
4. Every new module needs `variables.tf`, `main.tf`, `outputs.tf` — no other files.
5. Pass `module.tags.tags` as `tags` — never construct tags inline in a stack.
6. Run `terraform validate`, `terraform fmt -recursive`, `tflint`, and `checkov` before opening a PR.
