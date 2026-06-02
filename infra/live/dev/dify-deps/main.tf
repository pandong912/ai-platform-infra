locals {
  common_tags = {
    Project     = var.project
    Environment = var.environment
    Owner       = var.owner
    ManagedBy   = "opentofu"
    Component   = "dify-deps"
  }
}

data "aws_caller_identity" "current" {}

data "terraform_remote_state" "network" {
  backend = "s3"

  config = {
    bucket = var.state_bucket_name
    key    = var.network_state_key
    region = var.state_region
  }
}

data "terraform_remote_state" "eks" {
  backend = "s3"

  config = {
    bucket = var.state_bucket_name
    key    = var.eks_state_key
    region = var.state_region
  }
}

locals {
  oidc_provider_host = replace(
    data.terraform_remote_state.eks.outputs.oidc_provider_arn,
    "arn:aws:iam::${data.aws_caller_identity.current.account_id}:oidc-provider/",
    ""
  )
}

resource "aws_db_subnet_group" "dify" {
  name       = "${var.db_identifier}-subnets"
  subnet_ids = data.terraform_remote_state.network.outputs.private_subnet_ids
}

resource "aws_db_parameter_group" "dify" {
  name   = "${var.db_identifier}-pg"
  family = "postgres16"

  # PoC convenience: the community Dify chart does not expose a PostgreSQL
  # sslmode setting. Re-enable forced SSL with proper CA validation before prod.
  parameter {
    name  = "rds.force_ssl"
    value = "0"
  }
}

resource "aws_security_group" "dify_postgres" {
  name        = "${var.db_identifier}-postgres"
  description = "Allow PostgreSQL access to Dify RDS from EKS nodes"
  vpc_id      = data.terraform_remote_state.network.outputs.vpc_id
}

resource "aws_vpc_security_group_ingress_rule" "postgres_from_eks_nodes" {
  security_group_id            = aws_security_group.dify_postgres.id
  referenced_security_group_id = data.terraform_remote_state.eks.outputs.node_security_group_id
  ip_protocol                  = "tcp"
  from_port                    = 5432
  to_port                      = 5432
  description                  = "PostgreSQL from EKS worker nodes"
}

resource "aws_vpc_security_group_egress_rule" "postgres_all_egress" {
  security_group_id = aws_security_group.dify_postgres.id
  cidr_ipv4         = "0.0.0.0/0"
  ip_protocol       = "-1"
  description       = "Allow all egress"
}

resource "aws_db_instance" "dify" {
  identifier = var.db_identifier

  engine         = "postgres"
  engine_version = var.db_engine_version
  instance_class = var.db_instance_class

  allocated_storage     = var.db_allocated_storage
  max_allocated_storage = max(var.db_allocated_storage, 100)
  storage_encrypted     = true

  db_name  = var.db_name
  username = var.db_username
  password = var.db_password
  port     = 5432

  db_subnet_group_name   = aws_db_subnet_group.dify.name
  parameter_group_name   = aws_db_parameter_group.dify.name
  vpc_security_group_ids = [aws_security_group.dify_postgres.id]

  publicly_accessible     = false
  multi_az                = false
  deletion_protection     = false
  skip_final_snapshot     = true
  apply_immediately       = true
  copy_tags_to_snapshot   = true
  backup_retention_period = 1
}

resource "aws_elasticache_subnet_group" "dify" {
  name       = "${var.redis_cluster_id}-subnets"
  subnet_ids = data.terraform_remote_state.network.outputs.private_subnet_ids
}

resource "aws_security_group" "dify_redis" {
  name        = "${var.redis_cluster_id}-redis"
  description = "Allow Redis access to Dify ElastiCache from EKS nodes"
  vpc_id      = data.terraform_remote_state.network.outputs.vpc_id
}

resource "aws_vpc_security_group_ingress_rule" "redis_from_eks_nodes" {
  security_group_id            = aws_security_group.dify_redis.id
  referenced_security_group_id = data.terraform_remote_state.eks.outputs.node_security_group_id
  ip_protocol                  = "tcp"
  from_port                    = 6379
  to_port                      = 6379
  description                  = "Redis from EKS worker nodes"
}

resource "aws_vpc_security_group_egress_rule" "redis_all_egress" {
  security_group_id = aws_security_group.dify_redis.id
  cidr_ipv4         = "0.0.0.0/0"
  ip_protocol       = "-1"
  description       = "Allow all egress"
}

resource "aws_elasticache_cluster" "dify" {
  cluster_id           = var.redis_cluster_id
  engine               = "redis"
  engine_version       = "7.1"
  node_type            = var.redis_node_type
  num_cache_nodes      = 1
  parameter_group_name = "default.redis7"
  port                 = 6379
  subnet_group_name    = aws_elasticache_subnet_group.dify.name
  security_group_ids   = [aws_security_group.dify_redis.id]
}

resource "aws_s3_bucket" "dify" {
  bucket = var.dify_bucket_name
}

resource "aws_s3_bucket_public_access_block" "dify" {
  bucket = aws_s3_bucket.dify.id

  block_public_acls       = true
  block_public_policy     = true
  ignore_public_acls      = true
  restrict_public_buckets = true
}

resource "aws_s3_bucket_versioning" "dify" {
  bucket = aws_s3_bucket.dify.id

  versioning_configuration {
    status = "Enabled"
  }
}

resource "aws_s3_bucket_server_side_encryption_configuration" "dify" {
  bucket = aws_s3_bucket.dify.id

  rule {
    apply_server_side_encryption_by_default {
      sse_algorithm = "AES256"
    }
  }
}

data "aws_iam_policy_document" "dify_s3" {
  statement {
    sid    = "ListBucket"
    effect = "Allow"
    actions = [
      "s3:ListBucket",
    ]
    resources = [aws_s3_bucket.dify.arn]
  }

  statement {
    sid    = "ReadWriteObjects"
    effect = "Allow"
    actions = [
      "s3:AbortMultipartUpload",
      "s3:DeleteObject",
      "s3:GetObject",
      "s3:PutObject",
    ]
    resources = ["${aws_s3_bucket.dify.arn}/*"]
  }
}

resource "aws_iam_policy" "dify_s3" {
  name        = "${var.project}-${var.environment}-dify-s3"
  description = "Allow Dify pods to read and write the Dify S3 bucket."
  policy      = data.aws_iam_policy_document.dify_s3.json
}

data "aws_iam_policy_document" "dify_s3_assume_role" {
  statement {
    effect  = "Allow"
    actions = ["sts:AssumeRoleWithWebIdentity"]

    principals {
      type        = "Federated"
      identifiers = [data.terraform_remote_state.eks.outputs.oidc_provider_arn]
    }

    condition {
      test     = "StringEquals"
      variable = "${local.oidc_provider_host}:aud"
      values   = ["sts.amazonaws.com"]
    }

    condition {
      test     = "StringEquals"
      variable = "${local.oidc_provider_host}:sub"
      values   = ["system:serviceaccount:${var.dify_namespace}:${var.dify_service_account_name}"]
    }
  }
}

resource "aws_iam_role" "dify_s3" {
  name               = "${var.project}-${var.environment}-dify-s3"
  assume_role_policy = data.aws_iam_policy_document.dify_s3_assume_role.json
  description        = "IRSA role used by Dify pods to access S3."
}

resource "aws_iam_role_policy_attachment" "dify_s3" {
  role       = aws_iam_role.dify_s3.name
  policy_arn = aws_iam_policy.dify_s3.arn
}
