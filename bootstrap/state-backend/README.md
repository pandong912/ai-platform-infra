# OpenTofu State Backend

This root module creates the shared remote state backend for the PoC:

- S3 bucket for `.tfstate`
- DynamoDB table for state locking
- KMS key for state encryption

Run this module once with local AWS admin credentials:

```bash
cp terraform.tfvars.example terraform.tfvars
# edit terraform.tfvars and set a globally unique bucket name
tofu init
tofu plan
tofu apply
```

After apply, use the output values to create `backend.tf` files from the
`backend.tf.example` files in `infra/live/dev/*`.
