output "id" {
  description = "Bucket name / ID."
  value       = aws_s3_bucket.this.id
}

output "arn" {
  description = "Bucket ARN."
  value       = aws_s3_bucket.this.arn
}

output "bucket_domain_name" {
  description = "Bucket domain name (bucket.s3.amazonaws.com)."
  value       = aws_s3_bucket.this.bucket_domain_name
}

output "bucket_regional_domain_name" {
  description = "Region-specific domain name (bucket.s3.region.amazonaws.com)."
  value       = aws_s3_bucket.this.bucket_regional_domain_name
}

output "hosted_zone_id" {
  description = "Route 53 hosted zone ID for the bucket's region (useful for alias records)."
  value       = aws_s3_bucket.this.hosted_zone_id
}

output "tls_enforce_policy_json" {
  description = <<-EOT
    The TLS-only (DenyHTTP) policy document as JSON, always computed whether or
    not this module attaches it.

    For callers that set `manage_bucket_policy = false` and own the bucket
    policy themselves: feed this into their own
    `aws_iam_policy_document`'s `override_policy_documents` so the HTTPS
    requirement survives taking over policy ownership.
  EOT
  value       = data.aws_iam_policy_document.tls_enforce.json
}
