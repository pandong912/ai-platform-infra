variable "aws_region" {
  description = "AWS region."
  type        = string
  default     = "us-east-1"
}

variable "project" {
  description = "Project name used in resource names."
  type        = string
  default     = "ai-video-platform"
}

variable "environment" {
  description = "Environment name."
  type        = string
  default     = "dev"
}

variable "owner" {
  description = "Owner tag value."
  type        = string
  default     = "platform"
}

variable "github_owner" {
  description = "GitHub organization or user that owns both PoC repositories."
  type        = string
}

variable "infra_repo" {
  description = "GitHub repository name for infrastructure and GitOps config."
  type        = string
  default     = "ai-platform-infra"
}

variable "app_repo" {
  description = "GitHub repository name for the Spring Boot service."
  type        = string
  default     = "hello-springboot-service"
}

variable "deploy_branch" {
  description = "Protected branch used for PoC deployments."
  type        = string
  default     = "master"
}

variable "attach_admin_policy_to_infra_apply" {
  description = "Attach AdministratorAccess to infra apply role for PoC bootstrap. Replace with least-privilege policies before production."
  type        = bool
  default     = true
}
