variable "domain_name" {
  description = "Primary domain name for the certificate (e.g. 'example.com')."
  type        = string
}

variable "subject_alternative_names" {
  description = "Additional domain names (SANs) to include (e.g. ['*.example.com', 'api.example.com'])."
  type        = list(string)
  default     = []
}

variable "validation_method" {
  description = "Certificate validation method: 'DNS' (recommended) or 'EMAIL'."
  type        = string
  default     = "DNS"

  validation {
    condition     = contains(["DNS", "EMAIL"], var.validation_method)
    error_message = "validation_method must be 'DNS' or 'EMAIL'."
  }
}

variable "hosted_zone_id" {
  description = "Route 53 hosted zone ID for automatic DNS validation record creation. Required when validation_method = 'DNS'."
  type        = string
  default     = null
}

variable "wait_for_validation" {
  description = "Block until the certificate is issued and validated. Recommended true."
  type        = bool
  default     = true
}

variable "key_algorithm" {
  description = "Key algorithm: 'RSA_2048' (default), 'RSA_4096', 'EC_prime256v1', 'EC_secp384r1'."
  type        = string
  default     = "RSA_2048"
}

variable "tags" {
  description = "Tags applied to all resources."
  type        = map(string)
  default     = {}
}
