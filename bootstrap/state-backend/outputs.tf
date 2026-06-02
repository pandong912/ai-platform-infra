output "state_bucket_name" {
  description = "S3 bucket used for OpenTofu remote state."
  value       = aws_s3_bucket.tofu_state.bucket
}

output "lock_table_name" {
  description = "DynamoDB table used for OpenTofu state locking."
  value       = aws_dynamodb_table.tofu_locks.name
}

output "kms_key_arn" {
  description = "KMS key ARN used to encrypt OpenTofu state."
  value       = aws_kms_key.tofu_state.arn
}

output "backend_config_example" {
  description = "Backend block values for the dev environment root modules."
  value = {
    bucket         = aws_s3_bucket.tofu_state.bucket
    dynamodb_table = aws_dynamodb_table.tofu_locks.name
    region         = var.aws_region
    encrypt        = true
  }
}
