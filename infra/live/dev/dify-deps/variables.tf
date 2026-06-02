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
  default     = "ai-video-dify-dev"
}

variable "db_name" {
  description = "Initial Dify database name."
  type        = string
  default     = "dify"
}

variable "db_username" {
  description = "RDS master username."
  type        = string
  default     = "dify"
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

variable "redis_cluster_id" {
  description = "ElastiCache Redis cluster ID."
  type        = string
  default     = "ai-video-dify-dev"
}

variable "redis_node_type" {
  description = "ElastiCache Redis node type."
  type        = string
  default     = "cache.t4g.micro"
}

variable "dify_bucket_name" {
  description = "Globally unique S3 bucket name for Dify files and plugin storage."
  type        = string
}

variable "dify_namespace" {
  description = "Kubernetes namespace where Dify runs."
  type        = string
  default     = "dify"
}

variable "dify_service_account_name" {
  description = "Kubernetes service account used by Dify pods for S3 access."
  type        = string
  default     = "dify-s3-access"
}
