output "db_endpoint" {
  description = "Nacos RDS MySQL endpoint."
  value       = aws_db_instance.nacos.address
}

output "db_port" {
  description = "Nacos RDS MySQL port."
  value       = aws_db_instance.nacos.port
}

output "db_name" {
  description = "Nacos database name."
  value       = aws_db_instance.nacos.db_name
}

output "db_username" {
  description = "Nacos database username."
  value       = aws_db_instance.nacos.username
  sensitive   = true
}

output "secret_name" {
  description = "AWS Secrets Manager secret name consumed by External Secrets Operator."
  value       = aws_secretsmanager_secret.nacos.name
}
