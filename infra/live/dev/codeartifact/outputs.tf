output "domain_name" {
  description = "CodeArtifact domain name."
  value       = aws_codeartifact_domain.this.domain
}

output "domain_owner" {
  description = "AWS account ID that owns the CodeArtifact domain."
  value       = aws_codeartifact_domain.this.owner
}

output "internal_repository_name" {
  description = "Internal Maven repository name."
  value       = aws_codeartifact_repository.internal_maven.repository
}

output "maven_central_repository_name" {
  description = "Maven Central proxy repository name."
  value       = aws_codeartifact_repository.maven_central.repository
}

output "internal_repository_arn" {
  description = "Internal Maven repository ARN."
  value       = aws_codeartifact_repository.internal_maven.arn
}

output "maven_repository_endpoint_command" {
  description = "Command to fetch the Maven repository endpoint."
  value       = "aws codeartifact get-repository-endpoint --domain ${aws_codeartifact_domain.this.domain} --domain-owner ${aws_codeartifact_domain.this.owner} --repository ${aws_codeartifact_repository.internal_maven.repository} --format maven --query repositoryEndpoint --output text"
}
