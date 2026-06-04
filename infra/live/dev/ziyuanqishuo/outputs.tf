output "db_endpoint" {
  description = "Ziyuanqishuo RDS PostgreSQL endpoint."
  value       = aws_db_instance.ziyuanqishuo.address
}

output "db_port" {
  description = "Ziyuanqishuo RDS PostgreSQL port."
  value       = aws_db_instance.ziyuanqishuo.port
}

output "db_name" {
  description = "Ziyuanqishuo database name."
  value       = aws_db_instance.ziyuanqishuo.db_name
}

output "db_username" {
  description = "Ziyuanqishuo database username."
  value       = aws_db_instance.ziyuanqishuo.username
  sensitive   = true
}

output "repository_urls" {
  description = "ECR repository URLs."
  value = {
    for key, repository in aws_ecr_repository.repositories : key => repository.repository_url
  }
}

output "github_ci_role_arn" {
  description = "GitHub Actions role ARN for ziyuanqishuo."
  value       = aws_iam_role.github_ci.arn
}

output "media_bucket_name" {
  description = "S3 bucket name for Ziyuanqishuo media resources."
  value       = aws_s3_bucket.media.bucket
}

output "media_access_key_id" {
  description = "Access key ID for Ziyuanqishuo media S3 compatible access."
  value       = aws_iam_access_key.media.id
}

output "media_secret_access_key" {
  description = "Secret access key for Ziyuanqishuo media S3 compatible access."
  value       = aws_iam_access_key.media.secret
  sensitive   = true
}

output "media_s3_endpoint" {
  description = "S3 endpoint used by the app's MinIO-compatible storage implementation."
  value       = "https://s3.${var.aws_region}.amazonaws.com"
}

output "media_public_base_url" {
  description = "Public base URL for generated media URLs."
  value       = "https://s3.${var.aws_region}.amazonaws.com/${aws_s3_bucket.media.bucket}"
}
