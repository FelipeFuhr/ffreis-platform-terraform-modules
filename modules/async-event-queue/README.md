# async-event-queue

Canonical **one-directional event-consumer unit** for the fleet. Replaces always-on
Lambda Event Source Mappings (which poll SQS ~130K req/month per queue at idle and
have no tunable interval) with a tunable, no-ESM trigger.

```
producer ─► [input SNS topic] ─┬─ event_driven ─────────► [SQS + DLQ] ─ESM──► Lambda   (recommended)
                               ├─ real_time ───────────► Lambda ; on-failure ─► [SQS + DLQ]  (push)
                               ├─ near_real_time/batch ─► [SQS + DLQ] ─drain─► Lambda   (fallback; discouraged)
                               └─ (optional) ──────────► Firehose ─► [S3 archive]   (replay → ux-storyteller)
   Lambda ─sns:Publish(result)─► [output topic]   (= the NEXT unit's input; there is NO output queue)
```

Composes the in-repo `sqs` and `sns` primitives. **The durable queue always belongs to
the consumer** — a Lambda's "output" is just the next unit's input, which already buffers
it, so there is no producer-side output queue.

## consumer_mode

| mode | trigger | SQS role | latency | idle cost | use for |
|---|---|---|---|---|---|
| `event_driven` | SQS Event Source Mapping | primary buffer | ~seconds | ~$0.05/queue/mo (poll) | **rate-limited/expensive or bursty** downstream (Bedrock, Rekognition) — buffer + `maximum_concurrency` backpressure |
| `real_time` | SNS → Lambda subscription (push) | failure-only queue (empty in normal op) | < 1 s | ~0 | **low-volume, not-rate-limited** (SES, DDB writes) — forms, auth, notifications |
| `near_real_time` | EventBridge scheduled drain | primary buffer | = drain interval | drain-rate dependent | *fallback only — discouraged* (the disabled-drain footgun dropped fleet emails) |
| `batch` | EventBridge drain (cron) | primary buffer | 5 min–hours | very low | *fallback only* |
| `external` | caller wires the trigger | primary buffer | — | — | caller owns the trigger |

`event_driven` and `real_time` are the two recommended last hops; both sit behind the same
SNS bus + archive. The scheduled-drain modes (`near_real_time`/`batch`) are kept as a
documented **fallback and are not used by any website** — a scheduled drain left
`state = DISABLED` at go-live silently dropped admin emails across two sites (the
`esm_stalled` canary on `event_driven` exists to catch exactly that class of failure).

## Choosing a pattern (new forms / interactions)

Every async flow is **two independent choices**. Both sit behind the same SNS bus, so
observability and the envelope are identical regardless.

**Axis 1 — last hop (how the consumer is triggered):**

| Pick | When |
|---|---|
| **`event_driven`** (SNS→SQS→ESM) | the downstream is rate-limited or expensive (Bedrock, Rekognition, a throttled API) or traffic is bursty — you want the SQS buffer + `maximum_concurrency` backpressure. *The fleet default for pipeline work.* |
| **`real_time`** (SNS→Lambda push) | low/moderate volume, the downstream is not rate-limited (SES, a DDB write), and you want sub-second + zero idle cost — forms, auth, notifications. Set `real_time_subscription_dlq = true` + `create_failure_drain = false`. |

Never use `near_real_time`/`batch` for a website flow — they exist only as a documented fallback.

**Axis 2 — delivery (what the user sees):**

| Pick | When |
|---|---|
| **await-result** *(default)* | the user needs the outcome — show success only once the work is *processed* (email sent / request done), not when it was enqueued. Wire the **`async-job-status`** module: submit returns `202 {job_id}` (= the envelope `correlation_id`), the consumer's last step writes the terminal status, the browser polls `GET /api/status/{job_id}` via the tracker SDK's `submitAndAwait`. This is the honest-success contract — it's what makes "success" mean the work happened. |
| **ack-only** | genuinely best-effort side effects (analytics, a non-critical notification) — submit returns `202 {accepted}`, no job tracking. |

**Always, regardless of the two axes:**

1. **Publish a `DomainEvent`** (ffreis-rust-shared `v0.7.0` `shared::event` / ffreis-python-shared
   `v0.2.0`) to the input topic — one schema across producers, consumers, the status writer,
   and observability. Its `correlation_id` *is* the `job_id` and the ux `session_id`.
2. **`create_archive = true`** (except PII/auth) so every event lands in S3 — that archive is
   the **ux-storyteller** tap and the replay source. Observability reads the bus/archive
   (upstream of the push-vs-ESM split), so it's agnostic to the last hop.
3. **`create_alarms = true`** — non-negotiable. `event_driven` gets the `esm_stalled` canary;
   `real_time` gets the subscription-DLQ + SNS-delivery alarms. A go-live flag left off must
   *page*, never silently drop.

## Caller responsibilities (the module cannot enforce these)

1. **Idempotency (mandatory).** Every hop is at-least-once. Make the consumer idempotent
   at the *side effect* (e.g. `PutItem` with `attribute_not_exists`, or an `email_sent_at`
   guard) — never a status flag flipped *before* the work (a mid-flight crash would then
   drop the work). Write `status = complete` only *after* the side effect.
2. **Reserved concurrency.** For `near_real_time`/`batch`, set
   `reserved_concurrent_executions = 1` on the consumer Lambda module so overlapping drains
   can't double-process. The module does not own the Lambda and cannot set this.
3. **`QUEUE_URL` env var.** Set it to `module.<unit>.queue_url` on the consumer Lambda
   (the drain handler reads it). For `real_time` this is the failure queue.
4. **IAM.** Attach the module's `*_policy_json` outputs to the relevant Lambda
   `inline_policies` (the module never creates IAM role attachments).
5. **Go-live flags.** `event_driven`: keep `esm_enabled = false` until the handler ships, flip
   true at cutover (the ESM *can* be created disabled, so it's always present and the
   `esm_stalled` canary guards a forgotten flip). `real_time`: keep
   `real_time_subscription_enabled = false` and `failure_drain_enabled = false` until cutover
   (an SNS subscription cannot be created disabled, so creating it early would invoke an
   un-updated handler).
6. **Visibility timeout.** Set `visibility_timeout_seconds` ≥ the consumer Lambda timeout
   with margin (the existing 6× multiple is a good default).

## Archive + replay (D2)

`create_archive = true` archives every event on the input topic to S3 via Kinesis Firehose
(pay-per-use, no fixed cost), for full reprocessing. A separate replay job reads an S3
time-range and re-publishes to the input topic (use `replay_policy_json`); idempotency
makes that safe. DLQ re-drive covers *failed*-message replay separately.

> **⚠ NEVER `create_archive` on flows carrying secrets or PII.** Auth events contain
> plaintext passwords; archiving writes them to S3. Form events contain submitter PII.
> Archive is for non-secret content streams (e.g. a content-ingestion pipeline) only.

## Chaining

One unit per consumer. Chain by passing a unit's `output_topic_arn` as the next unit's
`external_input_topic_arn`; the downstream unit owns its input queue, queue policy, and
subscription. SNS fan-out is implicit — N downstream units subscribing their queues to one
output topic each get every (matching) message.

## Not yet supported

- `prevent_destroy`: Terraform requires `lifecycle.prevent_destroy` to be a literal (not a
  variable), and the in-repo `sqs` module does not expose it yet (see its
  `feat/prevent-destroy` branch). Manage destroy-protection there once it lands.

<!-- BEGIN_TF_DOCS -->
## Requirements

| Name | Version |
|------|---------|
| <a name="requirement_terraform"></a> [terraform](#requirement\_terraform) | >= 1.9.0, < 2.0.0 |
| <a name="requirement_aws"></a> [aws](#requirement\_aws) | >= 5.0 |

## Providers

| Name | Version |
|------|---------|
| <a name="provider_aws"></a> [aws](#provider\_aws) | >= 5.0 |

## Modules

| Name | Source | Version |
|------|--------|---------|
| <a name="module_input_topic"></a> [input\_topic](#module\_input\_topic) | ../sns | n/a |
| <a name="module_output_topic"></a> [output\_topic](#module\_output\_topic) | ../sns | n/a |
| <a name="module_queue"></a> [queue](#module\_queue) | ../sqs | n/a |

## Resources

| Name | Type |
|------|------|
| [aws_cloudwatch_event_rule.drain](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/cloudwatch_event_rule) | resource |
| [aws_cloudwatch_event_rule.failure_drain](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/cloudwatch_event_rule) | resource |
| [aws_cloudwatch_event_target.drain](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/cloudwatch_event_target) | resource |
| [aws_cloudwatch_event_target.failure_drain](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/cloudwatch_event_target) | resource |
| [aws_cloudwatch_metric_alarm.dlq_depth](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/cloudwatch_metric_alarm) | resource |
| [aws_cloudwatch_metric_alarm.esm_stalled](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/cloudwatch_metric_alarm) | resource |
| [aws_cloudwatch_metric_alarm.queue_age](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/cloudwatch_metric_alarm) | resource |
| [aws_cloudwatch_metric_alarm.queue_depth](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/cloudwatch_metric_alarm) | resource |
| [aws_iam_role.firehose](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/iam_role) | resource |
| [aws_iam_role.sns_to_firehose](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/iam_role) | resource |
| [aws_iam_role_policy.firehose_s3](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/iam_role_policy) | resource |
| [aws_iam_role_policy.sns_to_firehose](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/iam_role_policy) | resource |
| [aws_kinesis_firehose_delivery_stream.archive](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/kinesis_firehose_delivery_stream) | resource |
| [aws_lambda_event_source_mapping.consumer](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/lambda_event_source_mapping) | resource |
| [aws_lambda_function_event_invoke_config.on_failure](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/lambda_function_event_invoke_config) | resource |
| [aws_lambda_permission.drain](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/lambda_permission) | resource |
| [aws_lambda_permission.failure_drain](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/lambda_permission) | resource |
| [aws_lambda_permission.sns_invoke](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/lambda_permission) | resource |
| [aws_sns_topic_subscription.additional_input](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/sns_topic_subscription) | resource |
| [aws_sns_topic_subscription.archive](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/sns_topic_subscription) | resource |
| [aws_sns_topic_subscription.input_to_queue](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/sns_topic_subscription) | resource |
| [aws_sns_topic_subscription.output](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/sns_topic_subscription) | resource |
| [aws_sns_topic_subscription.topic_to_lambda](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/sns_topic_subscription) | resource |
| [aws_sqs_queue_policy.allow_sns](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/sqs_queue_policy) | resource |
| [aws_iam_policy_document.consumer](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/data-sources/iam_policy_document) | data source |
| [aws_iam_policy_document.dlq_consumer](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/data-sources/iam_policy_document) | data source |
| [aws_iam_policy_document.firehose_assume](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/data-sources/iam_policy_document) | data source |
| [aws_iam_policy_document.firehose_s3](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/data-sources/iam_policy_document) | data source |
| [aws_iam_policy_document.output_publisher](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/data-sources/iam_policy_document) | data source |
| [aws_iam_policy_document.producer](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/data-sources/iam_policy_document) | data source |
| [aws_iam_policy_document.queue_allow_sns](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/data-sources/iam_policy_document) | data source |
| [aws_iam_policy_document.replay](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/data-sources/iam_policy_document) | data source |
| [aws_iam_policy_document.sns_firehose](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/data-sources/iam_policy_document) | data source |
| [aws_iam_policy_document.sns_firehose_assume](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/data-sources/iam_policy_document) | data source |
| [aws_partition.current](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/data-sources/partition) | data source |

## Inputs

| Name | Description | Type | Default | Required |
|------|-------------|------|---------|:--------:|
| <a name="input_additional_input_subscriptions"></a> [additional\_input\_subscriptions](#input\_additional\_input\_subscriptions) | Extra non-SQS subscribers on the input topic (email/http/lambda). Map of name -> {protocol, endpoint, raw\_message\_delivery, filter\_policy}. | <pre>map(object({<br/>    protocol             = string<br/>    endpoint             = string<br/>    raw_message_delivery = optional(bool, false)<br/>    filter_policy        = optional(string, null)<br/>  }))</pre> | `{}` | no |
| <a name="input_alarm_age_threshold_seconds"></a> [alarm\_age\_threshold\_seconds](#input\_alarm\_age\_threshold\_seconds) | ApproximateAgeOfOldestMessage alarm threshold. | `number` | `600` | no |
| <a name="input_alarm_depth_threshold"></a> [alarm\_depth\_threshold](#input\_alarm\_depth\_threshold) | ApproximateNumberOfMessagesVisible alarm threshold (primary queue). For a real\_time failure queue the module uses 0 (any message = failure). | `number` | `50` | no |
| <a name="input_alarm_sns_topic_arn"></a> [alarm\_sns\_topic\_arn](#input\_alarm\_sns\_topic\_arn) | Ops SNS topic for alarm actions. Required when create\_alarms. | `string` | `null` | no |
| <a name="input_archive_bucket_name"></a> [archive\_bucket\_name](#input\_archive\_bucket\_name) | Existing S3 bucket name for the raw archive. Required when create\_archive. | `string` | `null` | no |
| <a name="input_archive_buffer_mb"></a> [archive\_buffer\_mb](#input\_archive\_buffer\_mb) | Firehose buffering size hint in MB (1-128). | `number` | `5` | no |
| <a name="input_archive_buffer_seconds"></a> [archive\_buffer\_seconds](#input\_archive\_buffer\_seconds) | Firehose buffering interval hint (60-900). Lower = fresher archive, more S3 PUTs. | `number` | `300` | no |
| <a name="input_archive_prefix"></a> [archive\_prefix](#input\_archive\_prefix) | S3 key prefix for this flow's archive. null = '<name>'. Firehose appends 'YYYY/MM/DD/HH/'. | `string` | `null` | no |
| <a name="input_batch_size"></a> [batch\_size](#input\_batch\_size) | event\_driven: ESM batch\_size (1-10000). Default 1 for clean per-message logs (fleet per-item-loop convention). | `number` | `1` | no |
| <a name="input_canary_age_threshold_seconds"></a> [canary\_age\_threshold\_seconds](#input\_canary\_age\_threshold\_seconds) | event\_driven: the esm\_stalled canary fires when the oldest message is older than this AND consumer invocations are zero (the 'trigger disabled / broken' guardrail). Lower = faster page, more false positives at adoption. | `number` | `120` | no |
| <a name="input_consumer_lambda_arn"></a> [consumer\_lambda\_arn](#input\_consumer\_lambda\_arn) | Consumer Lambda ARN. Required for real\_time/near\_real\_time/batch. | `string` | `null` | no |
| <a name="input_consumer_lambda_name"></a> [consumer\_lambda\_name](#input\_consumer\_lambda\_name) | Consumer Lambda function name (for lambda permissions + on-failure config + EventBridge target). Required for real\_time/near\_real\_time/batch. | `string` | `null` | no |
| <a name="input_consumer_mode"></a> [consumer\_mode](#input\_consumer\_mode) | event\_driven (SNS->SQS->Lambda via ESM; the fleet default for buffered/rate-limited work) \| real\_time (SNS->Lambda push) \| near\_real\_time (drain) \| batch (drain, cron) \| external (caller manages the trigger). | `string` | `"near_real_time"` | no |
| <a name="input_content_based_deduplication"></a> [content\_based\_deduplication](#input\_content\_based\_deduplication) | FIFO content-based dedup (FIFO only). | `bool` | `false` | no |
| <a name="input_create_alarms"></a> [create\_alarms](#input\_create\_alarms) | Create CloudWatch alarms (depth, age, DLQ depth) on the managed queues. | `bool` | `false` | no |
| <a name="input_create_archive"></a> [create\_archive](#input\_create\_archive) | Archive every event on the input topic to S3 via Kinesis Firehose (for full reprocessing replay). NEVER enable on flows carrying secrets/PII (e.g. auth passwords). Requires an input SNS topic (the archive subscribes to it). | `bool` | `false` | no |
| <a name="input_create_dlq"></a> [create\_dlq](#input\_create\_dlq) | Create a DLQ + redrive policy on the primary queue. | `bool` | `true` | no |
| <a name="input_create_failure_drain"></a> [create\_failure\_drain](#input\_create\_failure\_drain) | real\_time: create the scheduled failure-drain EventBridge rule at all. Set false for the subscription-DLQ pattern (no scheduled rule) — failures still land in the work queue (subscription DLQ + on-failure) and are alarmed + manually/automatically re-driven. Decoupled from create\_failure\_queue so on-failure capture can exist without a scheduled replay. | `bool` | `true` | no |
| <a name="input_create_failure_queue"></a> [create\_failure\_queue](#input\_create\_failure\_queue) | real\_time: wire the work queue as the Lambda async on-failure destination + create its scheduled failure-drain. The work queue (module.queue) is always created; false only disables this on-failure wiring/drain. | `bool` | `true` | no |
| <a name="input_create_input_topic"></a> [create\_input\_topic](#input\_create\_input\_topic) | Create an input SNS topic that fans into the queue. false = producers send directly to SQS (single-producer flows). | `bool` | `true` | no |
| <a name="input_create_output_topic"></a> [create\_output\_topic](#input\_create\_output\_topic) | Create a result/chain-anchor topic the Lambda publishes to. Only create it when a subscriber exists (an unsubscribed topic drops messages). | `bool` | `false` | no |
| <a name="input_delay_seconds"></a> [delay\_seconds](#input\_delay\_seconds) | SQS delivery delay (0-900). | `number` | `0` | no |
| <a name="input_dlq_retention_seconds"></a> [dlq\_retention\_seconds](#input\_dlq\_retention\_seconds) | DLQ retention (60-1209600; default 14 days, room to investigate). | `number` | `1209600` | no |
| <a name="input_drain_enabled"></a> [drain\_enabled](#input\_drain\_enabled) | Enable the drain EventBridge rule. Kept false until the drain-mode handler ships; flip true at go-live (Phase 4). | `bool` | `false` | no |
| <a name="input_drain_schedule_expression"></a> [drain\_schedule\_expression](#input\_drain\_schedule\_expression) | EventBridge rate/cron for the scheduled drain (near\_real\_time/batch). | `string` | `"rate(5 minutes)"` | no |
| <a name="input_esm_enabled"></a> [esm\_enabled](#input\_esm\_enabled) | event\_driven: enable the SQS Event Source Mapping. UNLIKE an SNS->Lambda subscription, an ESM CAN be created disabled, so the resource is always created in event\_driven mode and only its `enabled` toggles. Kept false at adoption; flip true at go-live (the esm\_stalled canary alarm guards against forgetting). | `bool` | `false` | no |
| <a name="input_esm_report_batch_item_failures"></a> [esm\_report\_batch\_item\_failures](#input\_esm\_report\_batch\_item\_failures) | event\_driven: add ReportBatchItemFailures to the ESM function\_response\_types. REQUIRES the consumer to return a partial-batch-failure response (batchItemFailures); otherwise a failed message is acked and never reaches the DLQ. Default true (DLQ-safe). | `bool` | `true` | no |
| <a name="input_external_input_topic_arn"></a> [external\_input\_topic\_arn](#input\_external\_input\_topic\_arn) | Subscribe the queue to a PRE-EXISTING topic (chaining: a previous unit's output\_topic\_arn) instead of creating one. Mutually exclusive with create\_input\_topic (set create\_input\_topic = false when supplying this). | `string` | `null` | no |
| <a name="input_failure_drain_enabled"></a> [failure\_drain\_enabled](#input\_failure\_drain\_enabled) | Enable the failure-drain EventBridge rule (so real\_time failures are not silently lost). Kept false until the handler ships; flip true at go-live. | `bool` | `false` | no |
| <a name="input_failure_drain_schedule_expression"></a> [failure\_drain\_schedule\_expression](#input\_failure\_drain\_schedule\_expression) | How often to replay the real\_time failure queue. | `string` | `"rate(15 minutes)"` | no |
| <a name="input_fifo"></a> [fifo](#input\_fifo) | FIFO queue + topic (auto-appends '.fifo'). Incompatible with consumer\_mode = real\_time (SNS FIFO cannot target Lambda). | `bool` | `false` | no |
| <a name="input_input_filter_policy"></a> [input\_filter\_policy](#input\_input\_filter\_policy) | JSON SNS filter policy on the topic->queue subscription (route event subtypes). | `string` | `null` | no |
| <a name="input_input_filter_policy_scope"></a> [input\_filter\_policy\_scope](#input\_input\_filter\_policy\_scope) | MessageAttributes \| MessageBody. | `string` | `"MessageAttributes"` | no |
| <a name="input_input_topic_name"></a> [input\_topic\_name](#input\_input\_topic\_name) | Override the input topic name. null = '<name>-events'. | `string` | `null` | no |
| <a name="input_kms_master_key_id"></a> [kms\_master\_key\_id](#input\_kms\_master\_key\_id) | Optional CMK for SSE. null = SQS-managed / AWS-managed SNS key (no fixed CMK cost; the org default). | `string` | `null` | no |
| <a name="input_max_message_size"></a> [max\_message\_size](#input\_max\_message\_size) | Max SQS message size in bytes (1024-262144). | `number` | `262144` | no |
| <a name="input_max_receive_count"></a> [max\_receive\_count](#input\_max\_receive\_count) | Deliveries before a message moves to the DLQ (3 for critical flows, 5 for background). | `number` | `5` | no |
| <a name="input_maximum_batching_window_in_seconds"></a> [maximum\_batching\_window\_in\_seconds](#input\_maximum\_batching\_window\_in\_seconds) | event\_driven: ESM batching window (0-300). 0 = no wait (lowest latency). | `number` | `0` | no |
| <a name="input_maximum_concurrency"></a> [maximum\_concurrency](#input\_maximum\_concurrency) | event\_driven: scaling\_config.maximum\_concurrency on the ESM (2-1000). Caps concurrent consumer invocations — the backpressure knob for rate-limited downstreams (Bedrock/Rekognition). null = omit scaling\_config (uncapped). | `number` | `null` | no |
| <a name="input_message_retention_seconds"></a> [message\_retention\_seconds](#input\_message\_retention\_seconds) | Primary queue message retention (60-1209600; default 4 days). | `number` | `345600` | no |
| <a name="input_name"></a> [name](#input\_name) | Base name for the unit. All resource names derive from it (e.g. '<name>', '<name>-dlq', '<name>-events'). | `string` | n/a | yes |
| <a name="input_output_subscriptions"></a> [output\_subscriptions](#input\_output\_subscriptions) | Subscribers on the output topic (non-SQS: webhook/email/lambda). A downstream SQS consumer should instead set external\_input\_topic\_arn = this output\_topic\_arn and own its own queue. | <pre>map(object({<br/>    protocol             = string<br/>    endpoint             = string<br/>    raw_message_delivery = optional(bool, false)<br/>    filter_policy        = optional(string, null)<br/>  }))</pre> | `{}` | no |
| <a name="input_output_topic_name"></a> [output\_topic\_name](#input\_output\_topic\_name) | Override the output topic name. null = '<name>-completed'. | `string` | `null` | no |
| <a name="input_raw_message_delivery"></a> [raw\_message\_delivery](#input\_raw\_message\_delivery) | true = SQS body is the raw producer JSON (no SNS envelope). Keep true so the drain handler reads the payload directly. | `bool` | `true` | no |
| <a name="input_real_time_input_filter_policy"></a> [real\_time\_input\_filter\_policy](#input\_real\_time\_input\_filter\_policy) | SNS filter policy on the topic->Lambda subscription (real\_time only). | `string` | `null` | no |
| <a name="input_real_time_subscription_dlq"></a> [real\_time\_subscription\_dlq](#input\_real\_time\_subscription\_dlq) | real\_time: attach a redrive\_policy to the SNS->Lambda subscription so messages SNS cannot DELIVER (Lambda throttled/unavailable) land in the work queue instead of being dropped. Pair with create\_failure\_drain = false for the truly-no-scheduled-rule push pattern. | `bool` | `false` | no |
| <a name="input_real_time_subscription_enabled"></a> [real\_time\_subscription\_enabled](#input\_real\_time\_subscription\_enabled) | Create the SNS->Lambda subscription + permission (real\_time). Kept false until the drain-mode handler ships (an SNS subscription cannot be created disabled; creating it early would invoke an un-updated handler). Flip true at go-live (Phase 4). | `bool` | `false` | no |
| <a name="input_receive_wait_time_seconds"></a> [receive\_wait\_time\_seconds](#input\_receive\_wait\_time\_seconds) | Long-poll wait time (0-20). 20 reduces empty-receive cost during drains. | `number` | `20` | no |
| <a name="input_tags"></a> [tags](#input\_tags) | Tags applied to all resources (use the tagging module output). | `map(string)` | `{}` | no |
| <a name="input_visibility_timeout_seconds"></a> [visibility\_timeout\_seconds](#input\_visibility\_timeout\_seconds) | SQS visibility timeout (0-43200). Set >= consumer Lambda timeout WITH MARGIN (the existing 6x multiple) so a slow drain run does not make a message visible mid-processing and get double-picked by the next tick. | `number` | `30` | no |

## Outputs

| Name | Description |
|------|-------------|
| <a name="output_archive_bucket_arn"></a> [archive\_bucket\_arn](#output\_archive\_bucket\_arn) | S3 archive bucket ARN (null if create\_archive = false). |
| <a name="output_archive_firehose_arn"></a> [archive\_firehose\_arn](#output\_archive\_firehose\_arn) | Firehose delivery stream ARN (null if create\_archive = false). |
| <a name="output_consumer_policy_json"></a> [consumer\_policy\_json](#output\_consumer\_policy\_json) | sqs:ReceiveMessage/DeleteMessage/GetQueueAttributes on the work queue (+ SendMessage in real\_time for the on-failure destination). |
| <a name="output_dlq_arn"></a> [dlq\_arn](#output\_dlq\_arn) | DLQ ARN (empty if create\_dlq = false). |
| <a name="output_dlq_consumer_policy_json"></a> [dlq\_consumer\_policy\_json](#output\_dlq\_consumer\_policy\_json) | Re-drive/inspection access to the DLQ (null if create\_dlq = false). |
| <a name="output_dlq_url"></a> [dlq\_url](#output\_dlq\_url) | DLQ URL (empty if create\_dlq = false). |
| <a name="output_input_topic_arn"></a> [input\_topic\_arn](#output\_input\_topic\_arn) | Input topic ARN — set as TOPIC\_ARN on the producer Lambda. null if create\_input\_topic = false and no external topic. |
| <a name="output_output_publisher_policy_json"></a> [output\_publisher\_policy\_json](#output\_output\_publisher\_policy\_json) | sns:Publish on the output topic (null if create\_output\_topic = false). |
| <a name="output_output_topic_arn"></a> [output\_topic\_arn](#output\_output\_topic\_arn) | Output/result topic ARN — set as OUTPUT\_TOPIC\_ARN on the consumer Lambda. null if create\_output\_topic = false. Chain by passing this as the next unit's external\_input\_topic\_arn. |
| <a name="output_producer_policy_json"></a> [producer\_policy\_json](#output\_producer\_policy\_json) | sns:Publish on the input topic (or sqs:SendMessage on the queue if no topic). |
| <a name="output_queue_arn"></a> [queue\_arn](#output\_queue\_arn) | Work queue ARN. |
| <a name="output_queue_name"></a> [queue\_name](#output\_queue\_name) | Work queue name (CloudWatch dimension). |
| <a name="output_queue_url"></a> [queue\_url](#output\_queue\_url) | Work queue URL — set as QUEUE\_URL on the consumer Lambda (drain reads it). |
| <a name="output_replay_policy_json"></a> [replay\_policy\_json](#output\_replay\_policy\_json) | s3:GetObject on the archive prefix + sns:Publish on the input topic, for the replay job (null if create\_archive = false). |
<!-- END_TF_DOCS -->