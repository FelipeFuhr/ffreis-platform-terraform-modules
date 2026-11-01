variable "name" {
  description = "Base name for the CloudFront function (environment suffix is appended automatically)."
  type        = string
}

variable "environment" {
  description = "Deployment environment (e.g. 'dev' or 'prod')."
  type        = string
}

variable "lang_prefixes" {
  description = "Ordered list of URL language prefixes. Used for both language routing and clean-URL detection. Pass an empty list ([]) for flat-mode: a single-language site served at the root with no /<lang>/ segment — language routing is skipped and only clean-URL / directory-index rewriting applies."
  type        = list(string)
}

variable "default_lang" {
  description = "Language prefix used when neither cookie nor country header produces a match."
  type        = string
}

variable "canonicalize_html" {
  description = "When true (default), .html URLs 301-redirect to their extensionless canonical and extensionless paths rewrite to /index.html (pretty URLs — for directory-structured sites). Set false for flat sites that serve <name>.html files directly (the .html 301 is skipped); extensionless and trailing-slash rewriting still apply so directory roots resolve to /index.html."
  type        = bool
  default     = true
}

variable "country_to_lang" {
  description = "Map of ISO 3166-1 alpha-2 country codes to language prefixes."
  type        = map(string)
  default     = {}
}

variable "passthrough_exact" {
  description = "Paths that bypass language routing. Matched as exact URI or exact-prefix (e.g. '/ask' matches '/ask' and '/ask/foo' but not '/askchat')."
  type        = list(string)
  default     = []
}

variable "passthrough_prefixes" {
  description = "URI prefixes that bypass language routing. Matched via startsWith (e.g. '/api/' matches '/api/contact')."
  type        = list(string)
  default     = []
}

variable "cookie_to_prefix" {
  description = "Optional map of preferred_lang cookie values to URL language prefixes. Use when cookie values differ from URL prefixes (e.g. cookie='ja' → URL prefix='jp'). When empty, the cookie value is matched directly against lang_prefixes."
  type        = map(string)
  default     = {}
}

variable "healthz_enabled" {
  description = "When true, a /healthz request returns 200 OK immediately, bypassing all IP and language gates."
  type        = bool
  default     = false
}

variable "ip_allowlist_enabled" {
  description = "When true, requests from IPs not in the allowlist receive 403. Typically true only in dev environments."
  type        = bool
  default     = false
}

variable "allowed_v4_ips_json" {
  description = "JSON-encoded array of allowed IPv4 addresses. Evaluated only when ip_allowlist_enabled is true."
  type        = string
  default     = "[]"
}

variable "allowed_v6_hex_prefixes_json" {
  description = "JSON-encoded array of allowed IPv6 hex prefixes. Evaluated only when ip_allowlist_enabled is true."
  type        = string
  default     = "[]"
}

variable "dev_access_secret" {
  description = "When non-empty, enables a cookie-based dev gate. Visit /<dev_access_path>?token=<value> once to receive a 30-day HttpOnly cookie granting access. Replaces the IP allowlist gate in dev environments."
  type        = string
  default     = ""
  sensitive   = true
}

variable "dev_access_path" {
  description = "URI path that accepts the token query parameter and sets the dev-access cookie. Defaults to /dev-access."
  type        = string
  default     = "/dev-access"
}

variable "dev_access_cookie_domain" {
  description = "When non-empty, sets the Domain attribute on the dev-access cookie (e.g. '.ffreis.com' to share the cookie across all subdomains). Leave empty to scope the cookie to the exact request host."
  type        = string
  default     = ""
}

variable "www_redirect_host" {
  description = "When non-empty, any request whose Host header starts with 'www.' is 301-redirected to 'https://<value><uri>'. Set to the bare apex domain (e.g. 'ffreis.com'). Leave empty to disable."
  type        = string
  default     = ""
}
