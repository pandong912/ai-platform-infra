output "db_endpoint" {
  description = "Temporal RDS PostgreSQL endpoint."
  value       = aws_db_instance.temporal.address
}

output "db_port" {
  description = "Temporal RDS PostgreSQL port."
  value       = aws_db_instance.temporal.port
}

output "db_name" {
  description = "Temporal default database name."
  value       = aws_db_instance.temporal.db_name
}

output "db_username" {
  description = "Temporal database username."
  value       = aws_db_instance.temporal.username
  sensitive   = true
}

output "visibility_database_name" {
  description = "Visibility database name to create before deploying Temporal."
  value       = "temporal_visibility"
}
