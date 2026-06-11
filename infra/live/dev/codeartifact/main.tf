locals {
  common_tags = {
    Project     = var.project
    Environment = var.environment
    Owner       = var.owner
    ManagedBy   = "opentofu"
    Component   = "codeartifact"
  }
}

resource "aws_codeartifact_domain" "this" {
  domain = var.domain_name
}

resource "aws_codeartifact_repository" "maven_central" {
  domain     = aws_codeartifact_domain.this.domain
  repository = var.upstream_repository_name

  external_connections {
    external_connection_name = "public:maven-central"
  }
}

resource "aws_codeartifact_repository" "internal_maven" {
  domain     = aws_codeartifact_domain.this.domain
  repository = var.repository_name

  upstream {
    repository_name = aws_codeartifact_repository.maven_central.repository
  }
}
