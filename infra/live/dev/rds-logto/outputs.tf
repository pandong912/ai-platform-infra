output "db_endpoint" {
  description = "RDS PostgreSQL endpoint."
  value       = aws_db_instance.logto.address
}

output "db_port" {
  description = "RDS PostgreSQL port."
  value       = aws_db_instance.logto.port
}

output "db_name" {
  description = "Logto database name."
  value       = aws_db_instance.logto.db_name
}

output "db_username" {
  description = "Logto database username."
  value       = aws_db_instance.logto.username
  sensitive   = true
}

output "db_url_template" {
  description = "PostgreSQL URL template. Replace PASSWORD before creating the Kubernetes Secret."
  value       = "postgresql://${var.db_username}:PASSWORD@${aws_db_instance.logto.address}:${aws_db_instance.logto.port}/${aws_db_instance.logto.db_name}"
  sensitive   = true
}
