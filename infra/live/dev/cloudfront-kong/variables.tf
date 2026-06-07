variable "aws_region" {
  description = "AWS region. CloudFront is global, but this is used for provider configuration and tags."
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

variable "origin_domain_name" {
  description = "Kong ALB DNS name, without protocol."
  type        = string
}

variable "price_class" {
  description = "CloudFront price class."
  type        = string
  default     = "PriceClass_100"
}

variable "comment" {
  description = "CloudFront distribution comment."
  type        = string
  default     = "Dev HTTPS entry for Kong ALB"
}

variable "enabled" {
  description = "Whether the CloudFront distribution is enabled."
  type        = bool
  default     = true
}
