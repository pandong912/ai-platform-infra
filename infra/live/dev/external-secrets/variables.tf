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

variable "state_bucket_name" {
  description = "S3 bucket that stores remote OpenTofu state."
  type        = string
}

variable "state_region" {
  description = "AWS region of the OpenTofu state bucket."
  type        = string
  default     = "us-east-1"
}

variable "eks_state_key" {
  description = "Remote state key for the EKS root module."
  type        = string
  default     = "dev/eks.tfstate"
}

variable "namespace" {
  description = "Namespace where External Secrets Operator runs."
  type        = string
  default     = "external-secrets"
}

variable "service_account_name" {
  description = "External Secrets Operator service account name."
  type        = string
  default     = "external-secrets"
}

variable "secrets_path_prefix" {
  description = "AWS Secrets Manager secret name prefix ESO can read."
  type        = string
  default     = "ai-video-platform/dev"
}
