output "external_secrets_role_arn" {
  description = "IRSA role ARN for External Secrets Operator."
  value       = aws_iam_role.external_secrets.arn
}

output "namespace" {
  description = "Namespace where External Secrets Operator runs."
  value       = var.namespace
}

output "service_account_name" {
  description = "External Secrets Operator service account name."
  value       = var.service_account_name
}

output "secrets_path_prefix" {
  description = "AWS Secrets Manager secret prefix ESO can read."
  value       = var.secrets_path_prefix
}
