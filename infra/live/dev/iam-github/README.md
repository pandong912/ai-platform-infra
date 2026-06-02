# GitHub Actions OIDC IAM

This module creates keyless GitHub Actions access to AWS:

- `infra_plan_role_arn`: for OpenTofu plan workflows.
- `infra_apply_role_arn`: for OpenTofu apply workflows on `master`.
- `app_ci_role_arn`: for the Spring Boot service CI workflow to push to ECR.

Usage:

```bash
cp backend.tf.example backend.tf
cp terraform.tfvars.example terraform.tfvars
# edit state backend bucket, AWS region, and GitHub owner
tofu init
tofu plan
tofu apply
```

GitHub private repositories on some plans do not enforce branch protection rules.
For this PoC, the IAM trust policy still limits AWS access to the configured
repository and `master` branch. For production, use GitHub Team/Enterprise branch
protection or GitHub Environments with required reviewers.

After apply, add these secrets or variables:

Infra repo:

- `AWS_REGION`
- `AWS_INFRA_PLAN_ROLE_ARN`
- `AWS_INFRA_APPLY_ROLE_ARN`

Application repo:

- `AWS_REGION`
- `AWS_APP_CI_ROLE_ARN`
- `GITOPS_REPO`
- `GITOPS_REPO_TOKEN`
