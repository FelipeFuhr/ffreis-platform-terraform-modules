# Render-only fixture: emits the viewer-request module's CloudFront Function
# source as a Terraform output so a test can execute the REAL rendered
# artifact under node, rather than asserting on the unrendered .tftpl (whose
# %{ if } directives mean the file on disk is never what CloudFront runs).
#
# No provider and no resources: `templatefile()` is a pure function, so this
# fixture needs neither AWS credentials nor an apply.

terraform {
  required_version = ">= 1.5.0, < 2.0.0"
}

variable "canonicalize_html" {
  description = "Whether the rendered function 301-canonicalises .html paths."
  type        = bool
  default     = true
}

variable "dev_access_secret" {
  description = "Non-empty enables the dev cookie gate in the rendered function."
  type        = string
  default     = ""
}

variable "www_redirect_host" {
  description = "Non-empty enables the www -> apex 301 in the rendered function."
  type        = string
  default     = ""
}

# Defaults reproduce the original two-language fixture exactly, so a test that
# does not set these renders byte-identically to before they existed.

variable "lang_prefixes" {
  description = "URL language prefixes. An empty list renders the function in flat-mode."
  type        = list(string)
  default     = ["en", "pt"]
}

variable "default_lang" {
  description = "Language prefix used when neither cookie nor country header matches. Empty in flat-mode."
  type        = string
  default     = "en"
}

variable "passthrough_prefixes" {
  description = "URI prefixes that bypass language routing, matched via startsWith."
  type        = list(string)
  default     = ["/api/"]
}

variable "country_to_lang" {
  description = "Country-code to language-prefix map. Empty in flat-mode."
  type        = map(string)
  default     = { BR = "pt" }
}

output "code" {
  description = "The rendered CloudFront Function source."
  value = templatefile("../../../modules/cloudfront-viewer-request/viewer_request.js.tftpl", {
    ip_allowlist_enabled         = false
    allowed_v4_ips_json          = "[]"
    allowed_v6_hex_prefixes_json = "[]"
    dev_gate_enabled             = var.dev_access_secret != ""
    dev_access_secret            = var.dev_access_secret
    dev_access_path              = "/dev-access"
    dev_cookie_domain_attr       = ""
    lang_prefixes_json           = jsonencode(var.lang_prefixes)
    default_lang                 = var.default_lang
    canonicalize_html            = var.canonicalize_html
    country_to_lang_json         = jsonencode(var.country_to_lang)
    passthrough_exact_json       = jsonencode([])
    passthrough_prefixes_json    = jsonencode(var.passthrough_prefixes)
    cookie_to_prefix_enabled     = false
    cookie_to_prefix_json        = jsonencode({})
    healthz_enabled              = true
    www_redirect_enabled         = var.www_redirect_host != ""
    www_redirect_host            = var.www_redirect_host
  })
}
