variable "name" {
  description = "DynamoDB table name."
  type        = string
}

variable "hash_key" {
  description = "Attribute name for the hash (partition) key."
  type        = string
}

variable "range_key" {
  description = "Attribute name for the range (sort) key. Leave empty for hash-only tables."
  type        = string
  default     = ""
}

variable "billing_mode" {
  description = "'PAY_PER_REQUEST' (default) or 'PROVISIONED'."
  type        = string
  default     = "PAY_PER_REQUEST"

  validation {
    condition     = contains(["PAY_PER_REQUEST", "PROVISIONED"], var.billing_mode)
    error_message = "billing_mode must be 'PAY_PER_REQUEST' or 'PROVISIONED'."
  }
}

variable "read_capacity" {
  description = "Read capacity units. Required when billing_mode = 'PROVISIONED'."
  type        = number
  default     = null
}

variable "write_capacity" {
  description = "Write capacity units. Required when billing_mode = 'PROVISIONED'."
  type        = number
  default     = null
}

variable "attributes" {
  description = <<-EOT
    Attribute definitions for keys and GSI/LSI keys.
    Type is "S" (string), "N" (number), or "B" (binary).
    The hash_key and range_key attributes are added automatically.
  EOT
  type = list(object({
    name = string
    type = string
  }))
  default = []
}

variable "global_secondary_indexes" {
  description = "Global secondary indexes."
  type = list(object({
    name               = string
    hash_key           = string
    range_key          = optional(string, null)
    projection_type    = optional(string, "ALL")
    non_key_attributes = optional(list(string), [])
    read_capacity      = optional(number, null)
    write_capacity     = optional(number, null)
  }))
  default = []
}

variable "ttl_attribute" {
  description = "Attribute name for TTL. Leave empty to disable TTL."
  type        = string
  default     = ""
}

variable "kms_master_key_id" {
  description = "KMS key ARN for SSE. Leave empty to use AWS-managed key (DEFAULT)."
  type        = string
  default     = null
}

variable "stream_enabled" {
  description = "Enable DynamoDB Streams."
  type        = bool
  default     = false
}

variable "stream_view_type" {
  description = "Stream view type when stream_enabled = true."
  type        = string
  default     = "NEW_AND_OLD_IMAGES"
}

variable "tags" {
  description = "Tags applied to the table."
  type        = map(string)
  default     = {}
}
