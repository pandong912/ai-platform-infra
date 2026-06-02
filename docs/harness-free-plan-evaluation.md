# Harness Free Plan Evaluation

Harness is optional for this PoC. The primary path is:

```text
GitHub Actions -> ECR -> GitOps repo -> Argo CD -> EKS
```

Evaluate Harness only after the primary path works.

## Option A: Replace GitHub Actions CI

Harness pipeline stages:

1. Clone `hello-springboot-service`.
2. Run `mvn --batch-mode clean test package`.
3. Build Docker image.
4. Push image to ECR.
5. Clone `ai-platform-infra`.
6. Update `gitops/apps/hello-springboot/values-dev.yaml`.
7. Commit and push the GitOps change.

Things to validate on the Free Plan:

- Cloud build credits are enough for repeated Maven and Docker builds.
- GitHub connector can access both private repositories.
- AWS connector can push to ECR without long-lived broad credentials.
- Harness Delegate is not required for the minimal path, or can run in EKS.

## Option B: Keep GitHub Actions CI, Use Harness for CD Governance

Harness pipeline stages:

1. Receive image tag or GitOps PR from GitHub Actions.
2. Require approval for non-dev environments.
3. Update GitOps values or merge the promotion PR.
4. Observe Argo CD sync.
5. Later add Continuous Verification using Prometheus, Datadog, or CloudWatch.

This is closer to the long-term architecture. Harness becomes the enterprise
delivery control plane, while Argo CD remains the GitOps reconciliation engine.

## Recommendation

For this PoC, do not block on Harness. Use GitHub Actions first, then compare:

- time to configure;
- quality of GitOps integration;
- approval and audit capabilities;
- ability to add deployment verification;
- cost and Free Plan limits.
