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

variable "repository_name" {
  description = "ECR repository name for the Spring Boot service."
  type        = string
  default     = "hello-springboot"
}

variable "max_images" {
  description = "Maximum number of images to keep."
  type        = number
  default     = 50
}
