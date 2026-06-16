output "db_endpoint" {
  description = "Flyte RDS PostgreSQL endpoint."
  value       = aws_db_instance.flyte.address
}

output "db_port" {
  description = "Flyte RDS PostgreSQL port."
  value       = aws_db_instance.flyte.port
}

output "db_name" {
  description = "Flyte database name."
  value       = aws_db_instance.flyte.db_name
}

output "db_username" {
  description = "Flyte database username."
  value       = aws_db_instance.flyte.username
  sensitive   = true
}

output "s3_bucket_name" {
  description = "Flyte S3 bucket name."
  value       = aws_s3_bucket.flyte.bucket
}

output "backend_role_arn" {
  description = "IRSA role ARN for Flyte backend services."
  value       = aws_iam_role.flyte_backend.arn
}

output "user_role_arn" {
  description = "Default IRSA role ARN for Flyte-launched task pods."
  value       = aws_iam_role.flyte_user.arn
}

output "flyte_namespace" {
  description = "Kubernetes namespace where Flyte runs."
  value       = var.flyte_namespace
}

output "backend_service_account_name" {
  description = "Flyte backend Kubernetes service account name."
  value       = var.flyte_backend_service_account_name
}

output "secret_name" {
  description = "AWS Secrets Manager secret name for Flyte."
  value       = aws_secretsmanager_secret.flyte.name
}
