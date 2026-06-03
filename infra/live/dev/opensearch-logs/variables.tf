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

variable "domain_name" {
  description = "OpenSearch domain name."
  type        = string
  default     = "ai-video-logs-dev"
}

variable "engine_version" {
  description = "OpenSearch engine version."
  type        = string
  default     = "OpenSearch_2.17"
}

variable "instance_type" {
  description = "OpenSearch instance type."
  type        = string
  default     = "t3.small.search"
}

variable "volume_size" {
  description = "OpenSearch EBS volume size in GiB."
  type        = number
  default     = 20
}

variable "fluent_bit_namespace" {
  description = "Namespace where Fluent Bit runs."
  type        = string
  default     = "logging"
}

variable "fluent_bit_service_account_name" {
  description = "Service account used by Fluent Bit."
  type        = string
  default     = "fluent-bit"
}
