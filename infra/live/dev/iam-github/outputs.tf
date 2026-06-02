output "github_oidc_provider_arn" {
  description = "GitHub Actions OIDC provider ARN."
  value       = aws_iam_openid_connect_provider.github.arn
}

output "infra_plan_role_arn" {
  description = "IAM role ARN used by infra PR plan workflows."
  value       = aws_iam_role.infra_plan.arn
}

output "infra_apply_role_arn" {
  description = "IAM role ARN used by infra apply workflows."
  value       = aws_iam_role.infra_apply.arn
}

output "app_ci_role_arn" {
  description = "IAM role ARN used by application CI to push images to ECR."
  value       = aws_iam_role.app_ci.arn
}
