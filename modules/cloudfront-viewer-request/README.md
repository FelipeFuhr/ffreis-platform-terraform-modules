# cloudfront-viewer-request

CloudFront Function (JS 2.0) for viewer-request events. A single template serves
the entire fleet; site-specific config is injected via `templatefile()`.

## Responsibilities (applied in order)

1. **Health check** — `/healthz` returns 200 OK unconditionally (optional).
2. **www redirect** — `Host: www.*` gets a 301 to the apex domain (enabled when `www_redirect_host` is set).
3. **Cookie gate** — visit `/<dev_access_path>?token=<secret>` once to get a 30-day HttpOnly cookie; all other requests must present that cookie. Enabled when `dev_access_secret` is set.
4. **Passthrough** — configured paths bypass all routing and rewriting.
5. **Language routing** — requests not on a language prefix are 302-redirected to `/<lang><uri>` using cookie → country → default priority.
6. **Clean-URL rewriting** — `.html` paths get a 301 canonical redirect; extensionless paths are rewritten to `/path/index.html` for the S3 fetch.

<!-- BEGIN_TF_DOCS -->
## Requirements

| Name | Version |
|------|---------|
| <a name="requirement_terraform"></a> [terraform](#requirement\_terraform) | >= 1.5.0, < 2.0.0 |
| <a name="requirement_aws"></a> [aws](#requirement\_aws) | >= 5.0 |

## Providers

| Name | Version |
|------|---------|
| <a name="provider_aws"></a> [aws](#provider\_aws) | >= 5.0 |

## Modules

No modules.

## Resources

| Name | Type |
|------|------|
| [aws_cloudfront_function.viewer_request](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/cloudfront_function) | resource |

## Inputs

| Name | Description | Type | Default | Required |
|------|-------------|------|---------|:--------:|
| <a name="input_allowed_v4_ips_json"></a> [allowed\_v4\_ips\_json](#input\_allowed\_v4\_ips\_json) | JSON-encoded array of allowed IPv4 addresses. Evaluated only when ip\_allowlist\_enabled is true. | `string` | `"[]"` | no |
| <a name="input_allowed_v6_hex_prefixes_json"></a> [allowed\_v6\_hex\_prefixes\_json](#input\_allowed\_v6\_hex\_prefixes\_json) | JSON-encoded array of allowed IPv6 hex prefixes. Evaluated only when ip\_allowlist\_enabled is true. | `string` | `"[]"` | no |
| <a name="input_canonicalize_html"></a> [canonicalize\_html](#input\_canonicalize\_html) | When true (default), .html URLs 301-redirect to their extensionless canonical and extensionless paths rewrite to /index.html (pretty URLs — for directory-structured sites). Set false for flat sites that serve <name>.html files directly (the .html 301 is skipped); extensionless and trailing-slash rewriting still apply so directory roots resolve to /index.html. | `bool` | `true` | no |
| <a name="input_cookie_to_prefix"></a> [cookie\_to\_prefix](#input\_cookie\_to\_prefix) | Optional map of preferred\_lang cookie values to URL language prefixes. Use when cookie values differ from URL prefixes (e.g. cookie='ja' → URL prefix='jp'). When empty, the cookie value is matched directly against lang\_prefixes. | `map(string)` | `{}` | no |
| <a name="input_country_to_lang"></a> [country\_to\_lang](#input\_country\_to\_lang) | Map of ISO 3166-1 alpha-2 country codes to language prefixes. | `map(string)` | `{}` | no |
| <a name="input_default_lang"></a> [default\_lang](#input\_default\_lang) | Language prefix used when neither cookie nor country header produces a match. | `string` | n/a | yes |
| <a name="input_dev_access_cookie_domain"></a> [dev\_access\_cookie\_domain](#input\_dev\_access\_cookie\_domain) | When non-empty, sets the Domain attribute on the dev-access cookie (e.g. '.ffreis.com' to share the cookie across all subdomains). Leave empty to scope the cookie to the exact request host. | `string` | `""` | no |
| <a name="input_dev_access_path"></a> [dev\_access\_path](#input\_dev\_access\_path) | URI path that accepts the token query parameter and sets the dev-access cookie. Defaults to /dev-access. | `string` | `"/dev-access"` | no |
| <a name="input_dev_access_secret"></a> [dev\_access\_secret](#input\_dev\_access\_secret) | When non-empty, enables a cookie-based dev gate. Visit /<dev\_access\_path>?token=<value> once to receive a 30-day HttpOnly cookie granting access. Replaces the IP allowlist gate in dev environments. | `string` | `""` | no |
| <a name="input_environment"></a> [environment](#input\_environment) | Deployment environment (e.g. 'dev' or 'prod'). | `string` | n/a | yes |
| <a name="input_healthz_enabled"></a> [healthz\_enabled](#input\_healthz\_enabled) | When true, a /healthz request returns 200 OK immediately, bypassing all IP and language gates. | `bool` | `false` | no |
| <a name="input_ip_allowlist_enabled"></a> [ip\_allowlist\_enabled](#input\_ip\_allowlist\_enabled) | When true, requests from IPs not in the allowlist receive 403. Typically true only in dev environments. | `bool` | `false` | no |
| <a name="input_lang_prefixes"></a> [lang\_prefixes](#input\_lang\_prefixes) | Ordered list of URL language prefixes. Used for both language routing and clean-URL detection. Pass an empty list ([]) for flat-mode: a single-language site served at the root with no /<lang>/ segment — language routing is skipped and only clean-URL / directory-index rewriting applies. | `list(string)` | n/a | yes |
| <a name="input_name"></a> [name](#input\_name) | Base name for the CloudFront function (environment suffix is appended automatically). | `string` | n/a | yes |
| <a name="input_passthrough_exact"></a> [passthrough\_exact](#input\_passthrough\_exact) | Paths that bypass language routing. Matched as exact URI or exact-prefix (e.g. '/ask' matches '/ask' and '/ask/foo' but not '/askchat'). | `list(string)` | `[]` | no |
| <a name="input_passthrough_prefixes"></a> [passthrough\_prefixes](#input\_passthrough\_prefixes) | URI prefixes that bypass language routing. Matched via startsWith (e.g. '/api/' matches '/api/contact'). | `list(string)` | `[]` | no |
| <a name="input_www_redirect_host"></a> [www\_redirect\_host](#input\_www\_redirect\_host) | When non-empty, any request whose Host header starts with 'www.' is 301-redirected to 'https://<value><uri>'. Set to the bare apex domain (e.g. 'ffreis.com'). Leave empty to disable. | `string` | `""` | no |

## Outputs

| Name | Description |
|------|-------------|
| <a name="output_arn"></a> [arn](#output\_arn) | ARN of the published CloudFront function. |
| <a name="output_name"></a> [name](#output\_name) | Name of the CloudFront function. |
<!-- END_TF_DOCS -->
