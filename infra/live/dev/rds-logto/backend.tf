terraform {
  backend "s3" {
    bucket         = "ai-video-platform"
    key            = "dev/rds-logto.tfstate"
    region         = "us-east-1"
    dynamodb_table = "ai-video-platform-dev-tofu-locks"
    encrypt        = true
  }
}
