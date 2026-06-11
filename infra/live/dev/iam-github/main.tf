locals {
  common_tags = {
    Project     = var.project
    Environment = var.environment
    Owner       = var.owner
    ManagedBy   = "opentofu"
    Component   = "github-oidc"
  }

  github_oidc_url = "https://token.actions.githubusercontent.com"

  infra_branch_subject = "repo:${var.github_owner}/${var.infra_repo}:ref:refs/heads/${var.deploy_branch}"
  app_branch_subject   = "repo:${var.github_owner}/${var.app_repo}:ref:refs/heads/${var.deploy_branch}"
  infra_pr_subject     = "repo:${var.github_owner}/${var.infra_repo}:pull_request"
}

data "tls_certificate" "github" {
  url = local.github_oidc_url
}

resource "aws_iam_openid_connect_provider" "github" {
  url             = local.github_oidc_url
  client_id_list  = ["sts.amazonaws.com"]
  thumbprint_list = [data.tls_certificate.github.certificates[0].sha1_fingerprint]
}

data "aws_iam_policy_document" "infra_plan_trust" {
  statement {
    effect  = "Allow"
    actions = ["sts:AssumeRoleWithWebIdentity"]

    principals {
      type        = "Federated"
      identifiers = [aws_iam_openid_connect_provider.github.arn]
    }

    condition {
      test     = "StringEquals"
      variable = "token.actions.githubusercontent.com:aud"
      values   = ["sts.amazonaws.com"]
    }

    condition {
      test     = "StringLike"
      variable = "token.actions.githubusercontent.com:sub"
      values = [
        local.infra_branch_subject,
        local.infra_pr_subject,
      ]
    }
  }
}

data "aws_iam_policy_document" "infra_apply_trust" {
  statement {
    effect  = "Allow"
    actions = ["sts:AssumeRoleWithWebIdentity"]

    principals {
      type        = "Federated"
      identifiers = [aws_iam_openid_connect_provider.github.arn]
    }

    condition {
      test     = "StringEquals"
      variable = "token.actions.githubusercontent.com:aud"
      values   = ["sts.amazonaws.com"]
    }

    condition {
      test     = "StringEquals"
      variable = "token.actions.githubusercontent.com:sub"
      values   = [local.infra_branch_subject]
    }
  }
}

data "aws_iam_policy_document" "app_ci_trust" {
  statement {
    effect  = "Allow"
    actions = ["sts:AssumeRoleWithWebIdentity"]

    principals {
      type        = "Federated"
      identifiers = [aws_iam_openid_connect_provider.github.arn]
    }

    condition {
      test     = "StringEquals"
      variable = "token.actions.githubusercontent.com:aud"
      values   = ["sts.amazonaws.com"]
    }

    condition {
      test     = "StringEquals"
      variable = "token.actions.githubusercontent.com:sub"
      values   = [local.app_branch_subject]
    }
  }
}

resource "aws_iam_role" "infra_plan" {
  name               = "${var.project}-${var.environment}-github-infra-plan"
  assume_role_policy = data.aws_iam_policy_document.infra_plan_trust.json
  description        = "GitHub Actions role for OpenTofu plan in ${var.infra_repo}."
}

resource "aws_iam_role_policy_attachment" "infra_plan_readonly" {
  role       = aws_iam_role.infra_plan.name
  policy_arn = "arn:aws:iam::aws:policy/ReadOnlyAccess"
}

data "aws_iam_policy_document" "infra_plan_state_access" {
  statement {
    sid    = "StateBucketRead"
    effect = "Allow"
    actions = [
      "s3:GetObject",
      "s3:ListBucket",
    ]
    resources = ["*"]
  }

  statement {
    sid    = "StateLockAccess"
    effect = "Allow"
    actions = [
      "dynamodb:DeleteItem",
      "dynamodb:GetItem",
      "dynamodb:PutItem",
      "dynamodb:UpdateItem",
    ]
    resources = ["*"]
  }
}

resource "aws_iam_policy" "infra_plan_state_access" {
  name        = "${var.project}-${var.environment}-github-infra-plan-state"
  description = "Allow OpenTofu plan role to read remote state and use DynamoDB locks."
  policy      = data.aws_iam_policy_document.infra_plan_state_access.json
}

resource "aws_iam_role_policy_attachment" "infra_plan_state_access" {
  role       = aws_iam_role.infra_plan.name
  policy_arn = aws_iam_policy.infra_plan_state_access.arn
}

resource "aws_iam_role" "infra_apply" {
  name               = "${var.project}-${var.environment}-github-infra-apply"
  assume_role_policy = data.aws_iam_policy_document.infra_apply_trust.json
  description        = "GitHub Actions role for OpenTofu apply in ${var.infra_repo}."
}

resource "aws_iam_role_policy_attachment" "infra_apply_admin" {
  count      = var.attach_admin_policy_to_infra_apply ? 1 : 0
  role       = aws_iam_role.infra_apply.name
  policy_arn = "arn:aws:iam::aws:policy/AdministratorAccess"
}

resource "aws_iam_role" "app_ci" {
  name               = "${var.project}-${var.environment}-github-app-ci"
  assume_role_policy = data.aws_iam_policy_document.app_ci_trust.json
  description        = "GitHub Actions role for application image build and ECR push in ${var.app_repo}."
}

data "aws_iam_policy_document" "app_ci" {
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
    resources = ["arn:aws:ecr:${var.aws_region}:*:repository/hello-springboot"]
  }

  statement {
    sid    = "CodeArtifactAuth"
    effect = "Allow"
    actions = [
      "codeartifact:GetAuthorizationToken",
      "sts:GetServiceBearerToken",
    ]
    resources = ["*"]
  }

  statement {
    sid    = "CodeArtifactMavenReadWrite"
    effect = "Allow"
    actions = [
      "codeartifact:DescribeDomain",
      "codeartifact:DescribePackageVersion",
      "codeartifact:DescribeRepository",
      "codeartifact:GetPackageVersionReadme",
      "codeartifact:GetRepositoryEndpoint",
      "codeartifact:ListPackageVersionAssets",
      "codeartifact:ListPackageVersionDependencies",
      "codeartifact:ListPackageVersions",
      "codeartifact:ListPackages",
      "codeartifact:PublishPackageVersion",
      "codeartifact:PutPackageMetadata",
      "codeartifact:ReadFromRepository",
    ]
    resources = ["*"]
  }
}

resource "aws_iam_policy" "app_ci" {
  name        = "${var.project}-${var.environment}-github-app-ci"
  description = "Allow GitHub Actions to push hello-springboot images to ECR."
  policy      = data.aws_iam_policy_document.app_ci.json
}

resource "aws_iam_role_policy_attachment" "app_ci" {
  role       = aws_iam_role.app_ci.name
  policy_arn = aws_iam_policy.app_ci.arn
}
