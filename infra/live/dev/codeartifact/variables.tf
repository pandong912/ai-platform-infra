variable "aws_region" {
  description = "AWS region."
  type        = string
  default     = "us-east-1"
}

variable "project" {
  description = "Project name."
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

variable "domain_name" {
  description = "CodeArtifact domain name."
  type        = string
  default     = "ai-video-platform"
}

variable "repository_name" {
  description = "Internal Maven repository name."
  type        = string
  default     = "maven-internal"
}

variable "upstream_repository_name" {
  description = "Repository name used to proxy Maven Central."
  type        = string
  default     = "maven-central"
}
