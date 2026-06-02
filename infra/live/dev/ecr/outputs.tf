output "repository_name" {
  description = "ECR repository name."
  value       = aws_ecr_repository.hello.name
}

output "repository_arn" {
  description = "ECR repository ARN."
  value       = aws_ecr_repository.hello.arn
}

output "repository_url" {
  description = "ECR repository URL."
  value       = aws_ecr_repository.hello.repository_url
}
