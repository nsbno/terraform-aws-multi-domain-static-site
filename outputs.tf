output "website_bucket_id" {
  description = "The ID of the S3 bucket used for the static site"
  value       = data.aws_s3_bucket.website_bucket.id
}

output "website_bucket_arn" {
  description = "The ARN of the S3 bucket used for the static site"
  value       = data.aws_s3_bucket.website_bucket.arn
}

output "bucket_policy" {
  description = "The IAM policy document applied to the S3 bucket"
  value       = var.use_oai ? data.aws_iam_policy_document.s3_policy_oai[0].json : data.aws_iam_policy_document.s3_policy_oac[0].json
}

output "cloudfront_distribution_id" {
  description = "The ID of the CloudFront distribution (useful for cache invalidation)"
  value       = aws_cloudfront_distribution.s3_distribution.id
}

output "cloudfront_distribution_arn" {
  description = "The ARN of the CloudFront distribution"
  value       = aws_cloudfront_distribution.s3_distribution.arn
}

output "cloudfront_distribution_domain_name" {
  description = "The domain name of the CloudFront distribution"
  value       = aws_cloudfront_distribution.s3_distribution.domain_name
}

output "certificate_arn" {
  description = "The ARN of the ACM certificate"
  value       = aws_acm_certificate.cert_website.arn
}

