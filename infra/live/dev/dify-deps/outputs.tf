output "db_endpoint" {
  description = "Dify RDS PostgreSQL endpoint."
  value       = aws_db_instance.dify.address
}

output "db_port" {
  description = "Dify RDS PostgreSQL port."
  value       = aws_db_instance.dify.port
}

output "db_name" {
  description = "Dify database name."
  value       = aws_db_instance.dify.db_name
}

output "db_username" {
  description = "Dify database username."
  value       = aws_db_instance.dify.username
  sensitive   = true
}

output "redis_endpoint" {
  description = "Dify ElastiCache Redis endpoint."
  value       = aws_elasticache_cluster.dify.cache_nodes[0].address
}

output "redis_port" {
  description = "Dify ElastiCache Redis port."
  value       = aws_elasticache_cluster.dify.port
}

output "s3_bucket_name" {
  description = "Dify S3 bucket name."
  value       = aws_s3_bucket.dify.bucket
}

output "s3_role_arn" {
  description = "IRSA role ARN for Dify S3 access."
  value       = aws_iam_role.dify_s3.arn
}

output "service_account_name" {
  description = "Kubernetes service account name expected by the Dify Helm values."
  value       = var.dify_service_account_name
}
