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
