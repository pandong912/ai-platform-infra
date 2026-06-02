terraform {
  backend "s3" {
    bucket         = "ai-video-platform"
    key            = "dev/iam-github.tfstate"
    region         = "us-east-1"
    dynamodb_table = "ai-video-platform-dev-tofu-locks"
    encrypt        = true
  }
}
