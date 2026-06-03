output "opensearch_domain_name" {
  description = "OpenSearch domain name."
  value       = aws_opensearch_domain.logs.domain_name
}

output "opensearch_endpoint" {
  description = "OpenSearch domain endpoint without https scheme."
  value       = aws_opensearch_domain.logs.endpoint
}

output "opensearch_dashboard_endpoint" {
  description = "OpenSearch Dashboards endpoint."
  value       = aws_opensearch_domain.logs.dashboard_endpoint
}

output "fluent_bit_role_arn" {
  description = "IRSA role ARN for Fluent Bit."
  value       = aws_iam_role.fluent_bit.arn
}

output "fluent_bit_namespace" {
  description = "Namespace where Fluent Bit should run."
  value       = var.fluent_bit_namespace
}

output "fluent_bit_service_account_name" {
  description = "Fluent Bit service account name."
  value       = var.fluent_bit_service_account_name
}
