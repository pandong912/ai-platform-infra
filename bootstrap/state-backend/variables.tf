variable "aws_region" {
  description = "AWS region used for the OpenTofu state backend."
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

variable "state_bucket_name" {
  description = "Globally unique S3 bucket name for OpenTofu state."
  type        = string
}

variable "lock_table_name" {
  description = "DynamoDB table name for OpenTofu state locking."
  type        = string
  default     = "ai-video-platform-dev-tofu-locks"
}

variable "owner" {
  description = "Owner tag value."
  type        = string
  default     = "platform"
}
