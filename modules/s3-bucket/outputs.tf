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
