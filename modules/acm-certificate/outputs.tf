output "arn" {
  description = "ACM certificate ARN."
  value       = aws_acm_certificate.this.arn
}

output "domain_name" {
  description = "Primary domain name."
  value       = aws_acm_certificate.this.domain_name
}

output "domain_validation_options" {
  description = "Domain validation options (DNS record details for manual validation)."
  value       = aws_acm_certificate.this.domain_validation_options
}

output "status" {
  description = "Certificate status: PENDING_VALIDATION | ISSUED | INACTIVE | EXPIRED | VALIDATION_TIMED_OUT | REVOKED | FAILED."
  value       = aws_acm_certificate.this.status
}
