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

variable "gitops_repo_url" {
  description = "Git URL for the ai-platform-infra repository."
  type        = string
}

variable "gitops_target_revision" {
  description = "Git revision watched by the root Argo CD Application."
  type        = string
  default     = "master"
}

variable "gitops_repo_username" {
  description = "Optional GitHub username for private GitOps repository access."
  type        = string
  default     = ""
}

variable "gitops_repo_password" {
  description = "Optional GitHub token for private GitOps repository access."
  type        = string
  default     = ""
  sensitive   = true
}
