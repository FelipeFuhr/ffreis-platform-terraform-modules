variable "name" {
  description = "Kinesis Data Stream name."
  type        = string
}

variable "stream_mode" {
  description = "'ON_DEMAND' (auto-scales, recommended) or 'PROVISIONED' (fixed shard count)."
  type        = string
  default     = "ON_DEMAND"

  validation {
    condition     = contains(["ON_DEMAND", "PROVISIONED"], var.stream_mode)
    error_message = "stream_mode must be 'ON_DEMAND' or 'PROVISIONED'."
  }
}

variable "shard_count" {
  description = "Number of shards. Required when stream_mode = 'PROVISIONED'."
  type        = number
  default     = null
}

variable "retention_period" {
  description = "Data retention period in hours (24–8760). Default 24h."
  type        = number
  default     = 24

  validation {
    condition     = var.retention_period >= 24 && var.retention_period <= 8760
    error_message = "retention_period must be between 24 and 8760 hours."
  }
}

variable "kms_key_id" {
  description = "KMS key ARN for server-side encryption. Use 'alias/aws/kinesis' for the AWS-managed key."
  type        = string
  default     = "alias/aws/kinesis"
}

variable "shard_level_metrics" {
  description = "Enhanced shard-level CloudWatch metrics to enable."
  type        = list(string)
  default = [
    "IncomingBytes",
    "IncomingRecords",
    "OutgoingBytes",
    "OutgoingRecords",
    "WriteProvisionedThroughputExceeded",
    "ReadProvisionedThroughputExceeded",
    "IteratorAgeMilliseconds",
  ]
}

variable "tags" {
  description = "Tags applied to all resources."
  type        = map(string)
  default     = {}
}
