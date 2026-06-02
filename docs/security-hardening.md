# Security and Governance Hardening

Apply these after the PoC path works.

## GitHub

- Use GitHub Team/Enterprise branch protection for private repositories if
  branch protection is required.
- Until then, keep destructive workflows as manual `workflow_dispatch` jobs.
- Use GitHub Environments with required reviewers for staging and production.
- Prefer GitHub App tokens over fine-grained PATs for GitOps write-back.

## AWS Access

- Use GitHub OIDC only. Do not store long-lived AWS access keys in GitHub.
- Replace PoC `AdministratorAccess` on `infra_apply` with least-privilege
  policies after the resource model stabilizes.
- Use separate roles for plan, apply, and application image publishing.
- Enable AWS IAM Access Analyzer for external access review.

## OpenTofu

- Keep remote state in S3 with versioning and KMS encryption.
- Use DynamoDB state locking.
- Run `tofu plan -refresh-only` on a schedule for drift detection.
- Apply infrastructure only from CI/CD or a break-glass workflow.
- Keep root modules small: network, ECR, EKS, Argo CD bootstrap, app resources.

## Container Supply Chain

- Keep ECR scan-on-push enabled.
- Add Trivy or Grype scan to the application workflow.
- Add SBOM generation after the first PoC works.
- Sign images with cosign before production.
- Promote the same image digest across environments.

## Kubernetes

- Enable Argo CD SSO and RBAC before sharing with multiple users.
- Use External Secrets with AWS Secrets Manager for application secrets.
- Add resource requests and limits to all workloads.
- Add NetworkPolicy once the CNI/network policy choice is made.
- Add Argo Rollouts for canary releases after the basic Deployment works.

## Observability

- Add OpenTelemetry Collector.
- Add Prometheus/Grafana or managed observability integration.
- Use deployment verification signals:
  - HTTP 5xx rate
  - p95/p99 latency
  - pod restart count
  - ALB target health
  - queue lag for worker services
  - GPU utilization for future AI workloads
