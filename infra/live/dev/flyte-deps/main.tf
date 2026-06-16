locals {
  common_tags = {
    Project     = var.project
    Environment = var.environment
    Owner       = var.owner
    ManagedBy   = "opentofu"
    Component   = "flyte-deps"
  }

  flyte_artifact_prefixes = [
    "metadata",
    "user-data",
    "dataset-builder",
    "raw-output",
  ]
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

resource "aws_db_subnet_group" "flyte" {
  name       = "${var.db_identifier}-subnets"
  subnet_ids = data.terraform_remote_state.network.outputs.private_subnet_ids
}

resource "aws_db_parameter_group" "flyte" {
  name   = "${var.db_identifier}-pg"
  family = "postgres16"

  # PoC convenience: enable TLS and certificate validation before production.
  parameter {
    name  = "rds.force_ssl"
    value = "0"
  }
}

resource "aws_security_group" "flyte_postgres" {
  name        = "${var.db_identifier}-postgres"
  description = "Allow PostgreSQL access to Flyte RDS from EKS nodes"
  vpc_id      = data.terraform_remote_state.network.outputs.vpc_id
}

resource "aws_vpc_security_group_ingress_rule" "postgres_from_eks_nodes" {
  security_group_id            = aws_security_group.flyte_postgres.id
  referenced_security_group_id = data.terraform_remote_state.eks.outputs.node_security_group_id
  ip_protocol                  = "tcp"
  from_port                    = 5432
  to_port                      = 5432
  description                  = "PostgreSQL from EKS worker nodes"
}

resource "aws_vpc_security_group_egress_rule" "postgres_all_egress" {
  security_group_id = aws_security_group.flyte_postgres.id
  cidr_ipv4         = "0.0.0.0/0"
  ip_protocol       = "-1"
  description       = "Allow all egress"
}

resource "aws_db_instance" "flyte" {
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

  db_subnet_group_name   = aws_db_subnet_group.flyte.name
  parameter_group_name   = aws_db_parameter_group.flyte.name
  vpc_security_group_ids = [aws_security_group.flyte_postgres.id]

  publicly_accessible     = false
  multi_az                = false
  deletion_protection     = false
  skip_final_snapshot     = true
  apply_immediately       = true
  copy_tags_to_snapshot   = true
  backup_retention_period = 1
}

resource "aws_s3_bucket" "flyte" {
  bucket = var.flyte_bucket_name
}

resource "aws_s3_bucket_public_access_block" "flyte" {
  bucket = aws_s3_bucket.flyte.id

  block_public_acls       = true
  block_public_policy     = true
  ignore_public_acls      = true
  restrict_public_buckets = true
}

resource "aws_s3_bucket_versioning" "flyte" {
  bucket = aws_s3_bucket.flyte.id

  versioning_configuration {
    status = "Enabled"
  }
}

resource "aws_s3_bucket_server_side_encryption_configuration" "flyte" {
  bucket = aws_s3_bucket.flyte.id

  rule {
    apply_server_side_encryption_by_default {
      sse_algorithm = "AES256"
    }
  }
}

data "aws_iam_policy_document" "flyte_s3" {
  statement {
    sid    = "ListBucket"
    effect = "Allow"
    actions = [
      "s3:ListBucket",
      "s3:GetBucketLocation",
    ]
    resources = [aws_s3_bucket.flyte.arn]
  }

  statement {
    sid    = "ReadWriteObjects"
    effect = "Allow"
    actions = [
      "s3:AbortMultipartUpload",
      "s3:DeleteObject",
      "s3:GetObject",
      "s3:ListMultipartUploadParts",
      "s3:PutObject",
    ]
    resources = ["${aws_s3_bucket.flyte.arn}/*"]
  }
}

resource "aws_iam_policy" "flyte_s3" {
  name        = "${var.project}-${var.environment}-flyte-s3"
  description = "Allow Flyte backend and task pods to read and write Flyte artifacts."
  policy      = data.aws_iam_policy_document.flyte_s3.json
}

data "aws_iam_policy_document" "flyte_backend_assume_role" {
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
      values   = ["system:serviceaccount:${var.flyte_namespace}:${var.flyte_backend_service_account_name}"]
    }
  }
}

data "aws_iam_policy_document" "flyte_user_assume_role" {
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
      values = [
        "system:serviceaccount:${var.flyte_user_namespace}:${var.flyte_user_service_account_name}",
        "system:serviceaccount:${var.spark_namespace}:${var.spark_service_account_name}",
        "system:serviceaccount:${var.ray_namespace}:${var.ray_service_account_name}",
      ]
    }
  }
}

resource "aws_iam_role" "flyte_backend" {
  name               = "${var.project}-${var.environment}-flyte-backend"
  assume_role_policy = data.aws_iam_policy_document.flyte_backend_assume_role.json
  description        = "IRSA role used by Flyte backend services."
}

resource "aws_iam_role" "flyte_user" {
  name               = "${var.project}-${var.environment}-flyte-user"
  assume_role_policy = data.aws_iam_policy_document.flyte_user_assume_role.json
  description        = "Default IRSA role used by Flyte-launched task pods."
}

resource "aws_iam_role_policy_attachment" "flyte_backend_s3" {
  role       = aws_iam_role.flyte_backend.name
  policy_arn = aws_iam_policy.flyte_s3.arn
}

resource "aws_iam_role_policy_attachment" "flyte_user_s3" {
  role       = aws_iam_role.flyte_user.name
  policy_arn = aws_iam_policy.flyte_s3.arn
}

resource "aws_secretsmanager_secret" "flyte" {
  name        = var.secret_name
  description = "Flyte PoC database credentials and artifact bucket settings."
}

resource "aws_secretsmanager_secret_version" "flyte" {
  secret_id = aws_secretsmanager_secret.flyte.id

  secret_string = jsonencode({
    db_host     = aws_db_instance.flyte.address
    db_port     = aws_db_instance.flyte.port
    db_name     = aws_db_instance.flyte.db_name
    db_username = aws_db_instance.flyte.username
    db_password = var.db_password
    s3_bucket   = aws_s3_bucket.flyte.bucket
    s3_region   = var.aws_region
  })
}
