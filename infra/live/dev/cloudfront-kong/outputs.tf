output "distribution_id" {
  description = "CloudFront distribution ID."
  value       = aws_cloudfront_distribution.kong.id
}

output "distribution_domain_name" {
  description = "CloudFront distribution domain name."
  value       = aws_cloudfront_distribution.kong.domain_name
}

output "https_base_url" {
  description = "CloudFront HTTPS base URL."
  value       = "https://${aws_cloudfront_distribution.kong.domain_name}"
}

output "hanzi_frontend_url" {
  description = "Hanzi frontend URL through CloudFront."
  value       = "https://${aws_cloudfront_distribution.kong.domain_name}/hanzi/app/"
}

output "hanzi_frontend_auth_url" {
  description = "Hanzi frontend auth URL through CloudFront."
  value       = "https://${aws_cloudfront_distribution.kong.domain_name}/hanzi/app/auth"
}

output "hanzi_frontend_callback_url" {
  description = "Redirect URI for Logto Cloud SPA application."
  value       = "https://${aws_cloudfront_distribution.kong.domain_name}/hanzi/app/auth/callback"
}

output "hanzi_frontend_post_logout_url" {
  description = "Post sign-out redirect URI for Logto Cloud SPA application."
  value       = "https://${aws_cloudfront_distribution.kong.domain_name}/hanzi/app/"
}
