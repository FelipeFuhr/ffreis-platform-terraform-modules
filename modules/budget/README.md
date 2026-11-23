<!-- BEGIN_TF_DOCS -->
## Requirements

| Name | Version |
|------|---------|
| <a name="requirement_terraform"></a> [terraform](#requirement\_terraform) | >= 1.5.0, < 2.0.0 |
| <a name="requirement_aws"></a> [aws](#requirement\_aws) | >= 5.0 |

## Providers

| Name | Version |
|------|---------|
| <a name="provider_aws"></a> [aws](#provider\_aws) | 6.73.0 |

## Modules

No modules.

## Resources

| Name | Type |
|------|------|
| [aws_budgets_budget.this](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/budgets_budget) | resource |
| [aws_budgets_budget_action.this](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/budgets_budget_action) | resource |
| [aws_iam_role.budget_action](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/iam_role) | resource |
| [aws_iam_role_policy.budget_action](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/iam_role_policy) | resource |
| [aws_caller_identity.current](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/data-sources/caller_identity) | data source |
| [aws_iam_policy_document.budget_action](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/data-sources/iam_policy_document) | data source |
| [aws_iam_policy_document.budget_action_assume](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/data-sources/iam_policy_document) | data source |
| [aws_partition.current](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/data-sources/partition) | data source |

## Inputs

| Name | Description | Type | Default | Required |
|------|-------------|------|---------|:--------:|
| <a name="input_action"></a> [action](#input\_action) | OPTIONAL enforcement action. Default null = OFF, i.e. notify-only, which is<br/>every existing caller's behaviour and stays unchanged.<br/><br/>The `notification` blocks above only ever send mail. An action is the one<br/>AWS mechanism that can actually STOP spend at a threshold, and the only<br/>control in the fleet that still works when a spend bug outruns a<br/>per-request guard (ffreis-genai-runtime/docs/DESIGN.md §6.3, §6.6 item 4).<br/><br/>Set exactly one of `iam` or `ssm`:<br/><br/>  iam — attach a policy to principals when the threshold trips. The usual<br/>    shape is an explicit-deny policy on the role that spends, e.g. Deny<br/>    bedrock:InvokeModel on a Lambda execution role. An explicit Deny beats<br/>    any Allow, so this is a hard stop no application code can bypass.<br/><br/>  ssm — stop EC2 or RDS instances by id, in a region you name.<br/><br/>BLAST RADIUS. An IAM action means "this principal can no longer make that<br/>call" until someone detaches the policy. That is a deliberate outage. Put it<br/>at 100% of a deliberately generous limit and let the per-request guard<br/>handle the normal case; do not use it as a routine throttle.<br/><br/>REHEARSING IT. `approval_model = "MANUAL"` makes the action wait for a human<br/>in the Budgets console instead of firing. Use it to confirm the threshold<br/>and targets are right before switching to AUTOMATIC — but note that while it<br/>is MANUAL this budget still cannot stop anything on its own.<br/><br/>REVERSAL IS MANUAL. AWS applies the action; it never un-applies it. Recovery<br/>is detaching the policy (or restarting the instances) by hand, so whoever<br/>owns the budget needs to know that and be on the subscriber list. | <pre>object({<br/>    # When to act. Defaults to 100% of actual spend — the generous-limit posture<br/>    # described above.<br/>    threshold_percent = optional(number, 100)<br/>    threshold_type    = optional(string, "PERCENTAGE")<br/>    notification_type = optional(string, "ACTUAL")<br/><br/>    # AUTOMATIC acts on its own; MANUAL waits for console approval. Defaults to<br/>    # AUTOMATIC because passing this object at all is opting in to enforcement —<br/>    # a MANUAL default would behave exactly like the notify-only module it<br/>    # replaces, which is the failure mode this variable exists to fix.<br/>    approval_model = optional(string, "AUTOMATIC")<br/><br/>    iam = optional(object({<br/>      policy_arn = string<br/>      roles      = optional(list(string), [])<br/>      groups     = optional(list(string), [])<br/>      users      = optional(list(string), [])<br/>    }))<br/><br/>    ssm = optional(object({<br/>      action_sub_type = string<br/>      instance_ids    = list(string)<br/>      # Required, not inherited from the provider: see the note on<br/>      # local.action_region in main.tf.<br/>      region = string<br/>    }))<br/><br/>    # Who is told the action fired. At least one is required by AWS — and by<br/>    # the reversal-is-manual note above.<br/>    subscriber_email_addresses = optional(list(string), [])<br/>    subscriber_sns_topic_arns  = optional(list(string), [])<br/><br/>    # Role AWS Budgets assumes to apply the action. Leave null and the module<br/>    # creates one scoped to exactly the policy and targets configured here.<br/>    execution_role_arn = optional(string)<br/>  })</pre> | `null` | no |
| <a name="input_alert_email_addresses"></a> [alert\_email\_addresses](#input\_alert\_email\_addresses) | Email addresses to notify when a threshold is breached. | `list(string)` | `[]` | no |
| <a name="input_alert_sns_arns"></a> [alert\_sns\_arns](#input\_alert\_sns\_arns) | SNS topic ARNs to notify when a threshold is breached. | `list(string)` | `[]` | no |
| <a name="input_alert_thresholds"></a> [alert\_thresholds](#input\_alert\_thresholds) | List of alert thresholds. Each entry fires an SNS notification when the<br/>threshold is breached.<br/>threshold\_percent: percentage of the budget limit (e.g. 80 = 80%).<br/>comparison\_operator: 'GREATER\_THAN' or 'EQUAL\_TO'.<br/>threshold\_type: 'PERCENTAGE' or 'ABSOLUTE\_VALUE'.<br/>notification\_type: 'ACTUAL' (real spend) or 'FORECASTED' (projected spend). | <pre>list(object({<br/>    threshold_percent   = number<br/>    comparison_operator = optional(string, "GREATER_THAN")<br/>    threshold_type      = optional(string, "PERCENTAGE")<br/>    notification_type   = optional(string, "ACTUAL")<br/>  }))</pre> | <pre>[<br/>  {<br/>    "notification_type": "ACTUAL",<br/>    "threshold_percent": 50<br/>  },<br/>  {<br/>    "notification_type": "ACTUAL",<br/>    "threshold_percent": 80<br/>  },<br/>  {<br/>    "notification_type": "ACTUAL",<br/>    "threshold_percent": 100<br/>  },<br/>  {<br/>    "notification_type": "FORECASTED",<br/>    "threshold_percent": 100<br/>  }<br/>]</pre> | no |
| <a name="input_budget_type"></a> [budget\_type](#input\_budget\_type) | 'COST' (default) or 'USAGE'. | `string` | `"COST"` | no |
| <a name="input_cost_filters"></a> [cost\_filters](#input\_cost\_filters) | Map of cost filter name → list of values (e.g. { Service = ['Amazon EC2'] }). | `map(list(string))` | `{}` | no |
| <a name="input_limit_amount"></a> [limit\_amount](#input\_limit\_amount) | Maximum spend in USD before alerts fire. | `number` | n/a | yes |
| <a name="input_name"></a> [name](#input\_name) | Budget name. | `string` | n/a | yes |
| <a name="input_tags"></a> [tags](#input\_tags) | Tags applied to the budget. | `map(string)` | `{}` | no |
| <a name="input_time_unit"></a> [time\_unit](#input\_time\_unit) | Budget reset period: 'MONTHLY', 'QUARTERLY', or 'ANNUALLY'. | `string` | `"MONTHLY"` | no |

## Outputs

| Name | Description |
|------|-------------|
| <a name="output_action_enforces"></a> [action\_enforces](#output\_action\_enforces) | True only when this budget can actually stop spend: an action exists AND it<br/>is AUTOMATIC. A MANUAL action waits for a human, so it enforces nothing on<br/>its own — assert on this in a policy check rather than on action\_id. |
| <a name="output_action_execution_role_arn"></a> [action\_execution\_role\_arn](#output\_action\_execution\_role\_arn) | Role AWS Budgets assumes to apply the action, or null when no action is configured. |
| <a name="output_action_id"></a> [action\_id](#output\_action\_id) | Budget action ID, or null when no enforcement action is configured (var.action = null). |
| <a name="output_id"></a> [id](#output\_id) | Budget ID. |
| <a name="output_name"></a> [name](#output\_name) | Budget name. |
<!-- END_TF_DOCS -->