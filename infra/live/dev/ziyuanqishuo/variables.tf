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

variable "network_state_key" {
  description = "Remote state key for the network root module."
  type        = string
  default     = "dev/network.tfstate"
}

variable "eks_state_key" {
  description = "Remote state key for the EKS root module."
  type        = string
  default     = "dev/eks.tfstate"
}

variable "db_identifier" {
  description = "RDS instance identifier."
  type        = string
  default     = "ziyuanqishuo-dev"
}

variable "db_name" {
  description = "Initial database name."
  type        = string
  default     = "ziyuanqishuo"
}

variable "db_username" {
  description = "RDS master username."
  type        = string
  default     = "ziyuanqishuo"
}

variable "db_password" {
  description = "RDS master password. Keep this only in local terraform.tfvars or a secure CI secret."
  type        = string
  sensitive   = true
}

variable "db_instance_class" {
  description = "RDS instance class."
  type        = string
  default     = "db.t4g.micro"
}

variable "db_allocated_storage" {
  description = "Allocated storage in GiB."
  type        = number
  default     = 20
}

variable "db_engine_version" {
  description = "PostgreSQL engine version."
  type        = string
  default     = "16.6"
}

variable "enable_public_db_access" {
  description = "Temporarily expose the RDS instance through public subnets. Use only with narrow /32 CIDRs."
  type        = bool
  default     = false
}

variable "allowed_db_client_cidrs" {
  description = "Public client CIDRs allowed to connect to RDS when enable_public_db_access is true."
  type        = list(string)
  default     = []

  validation {
    condition = alltrue([
      for cidr in var.allowed_db_client_cidrs : can(cidrhost(cidr, 0))
    ])
    error_message = "All allowed_db_client_cidrs values must be valid CIDR blocks."
  }
}

variable "github_owner" {
  description = "GitHub organization or user that owns the ziyuanqishuo repository."
  type        = string
  default     = "xiongtao00"
}

variable "github_repo" {
  description = "GitHub repository name."
  type        = string
  default     = "ziyuanqishuo"
}

variable "deploy_branch" {
  description = "Branch allowed to assume the app CI role."
  type        = string
  default     = "main"
}
