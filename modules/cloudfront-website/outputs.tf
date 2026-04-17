output "distribution_id" {
  description = "CloudFront distribution ID."
  value       = aws_cloudfront_distribution.website.id
}

output "distribution_domain_name" {
  description = "CloudFront distribution domain name (*.cloudfront.net). Use as the alias target for Route 53 records."
  value       = aws_cloudfront_distribution.website.domain_name
}

output "distribution_hosted_zone_id" {
  description = "Route 53 hosted zone ID for the CloudFront distribution. Use with alias records."
  value       = aws_cloudfront_distribution.website.hosted_zone_id
}

output "distribution_arn" {
  description = "CloudFront distribution ARN."
  value       = aws_cloudfront_distribution.website.arn
}

output "bucket_id" {
  description = "S3 bucket name (ID)."
  value       = aws_s3_bucket.website.id
}

output "bucket_arn" {
  description = "S3 bucket ARN."
  value       = aws_s3_bucket.website.arn
}

output "bucket_regional_domain_name" {
  description = "S3 bucket regional domain name."
  value       = aws_s3_bucket.website.bucket_regional_domain_name
}

output "cloudfront_url" {
  description = "Direct HTTPS URL to the CloudFront distribution. Use this to verify the distribution works before DNS propagation."
  value       = "https://${aws_cloudfront_distribution.website.domain_name}/"
}

output "encryption_algorithm" {
  description = "S3 bucket encryption algorithm in use (AES256 = SSE-S3, aws:kms = SSE-KMS)."
  value       = aws_s3_bucket_server_side_encryption_configuration.website.rule[0].apply_server_side_encryption_by_default[0].sse_algorithm
}
