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

variable "media_bucket_name" {
  description = "Globally unique S3 bucket name for Ziyuanqishuo media resources."
  type        = string
  default     = "ziyuanqishuo-hanzi-dev"
}

variable "media_iam_user_name" {
  description = "IAM user name for application-level S3 compatible access."
  type        = string
  default     = "ziyuanqishuo-dev-media"
}

variable "media_cdn_enabled" {
  description = "Whether the dedicated Hanzi media CloudFront distribution is enabled."
  type        = bool
  default     = true
}

variable "media_cdn_price_class" {
  description = "CloudFront price class for the dedicated Hanzi media CDN."
  type        = string
  default     = "PriceClass_100"
}

variable "media_cdn_comment" {
  description = "CloudFront distribution comment for the dedicated Hanzi media CDN."
  type        = string
  default     = "Dedicated CDN for Ziyuanqishuo Hanzi media"
}

variable "content_cache_redis_cluster_id" {
  description = "ElastiCache Redis cluster ID for hanzi-content L2 cache."
  type        = string
  default     = "ziyuanqishuo-content-cache-dev"
}

variable "content_cache_redis_node_type" {
  description = "ElastiCache Redis node type for hanzi-content L2 cache."
  type        = string
  default     = "cache.t4g.micro"
}

