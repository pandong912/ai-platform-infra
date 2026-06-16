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
  description = "RDS instance identifier for Flyte metadata."
  type        = string
  default     = "ai-video-flyte-dev"
}

variable "db_name" {
  description = "Initial Flyte database name."
  type        = string
  default     = "flyte"
}

variable "db_username" {
  description = "RDS master username."
  type        = string
  default     = "flyte"
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

variable "flyte_bucket_name" {
  description = "Globally unique S3 bucket name for Flyte metadata and task artifacts."
  type        = string
}

variable "flyte_namespace" {
  description = "Kubernetes namespace where Flyte runs."
  type        = string
  default     = "flyte"
}

variable "flyte_backend_service_account_name" {
  description = "Kubernetes service account used by Flyte backend pods."
  type        = string
  default     = "flyte-backend"
}

variable "flyte_user_namespace" {
  description = "Default Kubernetes namespace used by Flyte user task executions."
  type        = string
  default     = "flytesnacks-development"
}

variable "flyte_user_service_account_name" {
  description = "Default Kubernetes service account used by Flyte user task executions."
  type        = string
  default     = "default"
}

variable "spark_namespace" {
  description = "Kubernetes namespace used by Spark applications launched from Flyte."
  type        = string
  default     = "spark-jobs"
}

variable "spark_service_account_name" {
  description = "Kubernetes service account used by Spark applications."
  type        = string
  default     = "spark"
}

variable "ray_namespace" {
  description = "Kubernetes namespace used by Ray jobs launched from Flyte."
  type        = string
  default     = "ray-jobs"
}

variable "ray_service_account_name" {
  description = "Kubernetes service account used by Ray jobs."
  type        = string
  default     = "ray"
}

variable "secret_name" {
  description = "AWS Secrets Manager secret name for Flyte database credentials."
  type        = string
  default     = "ai-video-platform/dev/flyte"
}
