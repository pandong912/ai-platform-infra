locals {
  common_tags = {
    Project     = var.project
    Environment = var.environment
    Owner       = var.owner
    ManagedBy   = "opentofu"
    Component   = "ziyuanqishuo"
  }

  repositories = toset([
    "ziyuanqishuo-content",
    "ziyuanqishuo-management",
    "ziyuanqishuo-db-migration",
  ])
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
  github_oidc_url = "https://token.actions.githubusercontent.com"
  github_subject  = "repo:${var.github_owner}/${var.github_repo}:ref:refs/heads/${var.deploy_branch}"
}

resource "aws_ecr_repository" "repositories" {
  for_each             = local.repositories
  name                 = each.value
  image_tag_mutability = "MUTABLE"

  image_scanning_configuration {
    scan_on_push = true
  }

  encryption_configuration {
    encryption_type = "AES256"
  }
}

resource "aws_ecr_lifecycle_policy" "repositories" {
  for_each   = aws_ecr_repository.repositories
  repository = each.value.name

  policy = jsonencode({
    rules = [
      {
        rulePriority = 1
        description  = "Keep the most recent 50 images"
        selection = {
          tagStatus   = "any"
          countType   = "imageCountMoreThan"
          countNumber = 50
        }
        action = {
          type = "expire"
        }
      }
    ]
  })
}

resource "aws_s3_bucket" "media" {
  bucket = var.media_bucket_name
}

resource "aws_s3_bucket_public_access_block" "media" {
  bucket = aws_s3_bucket.media.id

  block_public_acls       = true
  block_public_policy     = true
  ignore_public_acls      = true
  restrict_public_buckets = true
}

resource "aws_s3_bucket_versioning" "media" {
  bucket = aws_s3_bucket.media.id

  versioning_configuration {
    status = "Enabled"
  }
}

resource "aws_s3_bucket_server_side_encryption_configuration" "media" {
  bucket = aws_s3_bucket.media.id

  rule {
    apply_server_side_encryption_by_default {
      sse_algorithm = "AES256"
    }
  }
}

resource "aws_iam_user" "media" {
  name = var.media_iam_user_name
}

resource "aws_iam_access_key" "media" {
  user = aws_iam_user.media.name
}

data "aws_iam_policy_document" "media" {
  statement {
    sid    = "ListBucket"
    effect = "Allow"
    actions = [
      "s3:ListBucket",
    ]
    resources = [aws_s3_bucket.media.arn]
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
    resources = ["${aws_s3_bucket.media.arn}/*"]
  }
}

resource "aws_iam_user_policy" "media" {
  name   = "${var.media_iam_user_name}-s3"
  user   = aws_iam_user.media.name
  policy = data.aws_iam_policy_document.media.json
}

resource "aws_db_subnet_group" "ziyuanqishuo" {
  name       = "${var.db_identifier}-subnets"
  subnet_ids = data.terraform_remote_state.network.outputs.private_subnet_ids
}

resource "aws_db_parameter_group" "ziyuanqishuo" {
  name   = "${var.db_identifier}-pg"
  family = "postgres16"

  # PoC convenience: app currently uses default JDBC connection without sslmode.
  parameter {
    name  = "rds.force_ssl"
    value = "0"
  }
}

resource "aws_security_group" "postgres" {
  name        = "${var.db_identifier}-postgres"
  description = "Allow PostgreSQL access to Ziyuanqishuo RDS from EKS nodes"
  vpc_id      = data.terraform_remote_state.network.outputs.vpc_id
}

resource "aws_vpc_security_group_ingress_rule" "postgres_from_eks_nodes" {
  security_group_id            = aws_security_group.postgres.id
  referenced_security_group_id = data.terraform_remote_state.eks.outputs.node_security_group_id
  ip_protocol                  = "tcp"
  from_port                    = 5432
  to_port                      = 5432
  description                  = "PostgreSQL from EKS worker nodes"
}

resource "aws_vpc_security_group_ingress_rule" "postgres_from_public_clients" {
  for_each = toset([])

  security_group_id = aws_security_group.postgres.id
  cidr_ipv4         = each.value
  ip_protocol       = "tcp"
  from_port         = 5432
  to_port           = 5432
  description       = "Unused: direct public RDS access is intentionally disabled"
}

resource "aws_vpc_security_group_egress_rule" "postgres_all_egress" {
  security_group_id = aws_security_group.postgres.id
  cidr_ipv4         = "0.0.0.0/0"
  ip_protocol       = "-1"
  description       = "Allow all egress"
}

resource "aws_db_instance" "ziyuanqishuo" {
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

  db_subnet_group_name   = aws_db_subnet_group.ziyuanqishuo.name
  parameter_group_name   = aws_db_parameter_group.ziyuanqishuo.name
  vpc_security_group_ids = [aws_security_group.postgres.id]

  publicly_accessible     = false
  multi_az                = false
  deletion_protection     = false
  skip_final_snapshot     = true
  apply_immediately       = true
  copy_tags_to_snapshot   = true
  backup_retention_period = 1
}

data "aws_iam_openid_connect_provider" "github" {
  url = local.github_oidc_url
}

data "aws_iam_policy_document" "github_ci_trust" {
  statement {
    effect  = "Allow"
    actions = ["sts:AssumeRoleWithWebIdentity"]

    principals {
      type        = "Federated"
      identifiers = [data.aws_iam_openid_connect_provider.github.arn]
    }

    condition {
      test     = "StringEquals"
      variable = "token.actions.githubusercontent.com:aud"
      values   = ["sts.amazonaws.com"]
    }

    condition {
      test     = "StringEquals"
      variable = "token.actions.githubusercontent.com:sub"
      values   = [local.github_subject]
    }
  }
}

resource "aws_iam_role" "github_ci" {
  name               = "${var.project}-${var.environment}-ziyuanqishuo-ci"
  assume_role_policy = data.aws_iam_policy_document.github_ci_trust.json
  description        = "GitHub Actions role for ziyuanqishuo backend image builds."
}

data "aws_iam_policy_document" "github_ci" {
  statement {
    sid    = "EcrAuth"
    effect = "Allow"
    actions = [
      "ecr:GetAuthorizationToken",
      "sts:GetCallerIdentity",
    ]
    resources = ["*"]
  }

  statement {
    sid    = "EcrPushPull"
    effect = "Allow"
    actions = [
      "ecr:BatchCheckLayerAvailability",
      "ecr:BatchGetImage",
      "ecr:CompleteLayerUpload",
      "ecr:DescribeImages",
      "ecr:DescribeRepositories",
      "ecr:GetDownloadUrlForLayer",
      "ecr:InitiateLayerUpload",
      "ecr:ListImages",
      "ecr:PutImage",
      "ecr:UploadLayerPart",
    ]
    resources = [
      for repository in aws_ecr_repository.repositories : repository.arn
    ]
  }
}

resource "aws_iam_policy" "github_ci" {
  name        = "${var.project}-${var.environment}-ziyuanqishuo-ci"
  description = "Allow GitHub Actions to push Ziyuanqishuo images to ECR."
  policy      = data.aws_iam_policy_document.github_ci.json
}

resource "aws_iam_role_policy_attachment" "github_ci" {
  role       = aws_iam_role.github_ci.name
  policy_arn = aws_iam_policy.github_ci.arn
}
