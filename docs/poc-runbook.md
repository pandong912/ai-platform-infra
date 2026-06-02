# EKS CI/CD PoC Runbook

Use this runbook after AWS credentials, GitHub repositories, and required
secrets are configured.

## 1. Bootstrap State

```bash
cd bootstrap/state-backend
cp terraform.tfvars.example terraform.tfvars
tofu init
tofu apply
```

## 2. Configure Backends

For each root module under `infra/live/dev/*`:

```bash
cp backend.tf.example backend.tf
```

Replace:

- `REPLACE_WITH_STATE_BUCKET`
- `region`
- `dynamodb_table`

## 3. Apply Infrastructure

Apply in this order:

```bash
cd infra/live/dev/iam-github && tofu init && tofu apply
cd ../network && tofu init && tofu apply
cd ../ecr && tofu init && tofu apply
cd ../eks && tofu init && tofu apply
```

Set GitHub secrets and variables from `iam-github` outputs before expecting
GitHub Actions to work.

## 4. Patch GitOps Placeholders

Replace GitHub URL placeholders:

```bash
grep -R "REPLACE_WITH_GITHUB_USER_OR_ORG" -n gitops
```

Replace the AWS Load Balancer Controller role ARN:

```bash
grep -R "REPLACE_WITH_AWS_LOAD_BALANCER_CONTROLLER_ROLE_ARN" -n gitops
```

The hello image repository is updated automatically by application CI after the
first successful push to ECR.

## 5. Bootstrap Argo CD

```bash
cd infra/live/dev/argocd-bootstrap
cp backend.tf.example backend.tf
cp terraform.tfvars.example terraform.tfvars
tofu init
tofu apply
```

## 6. Verify Argo CD

```bash
aws eks update-kubeconfig --region us-east-1 --name ai-video-poc-dev
kubectl get pods -n argocd
kubectl get applications -n argocd
```

## 7. Trigger Application Deployment

Push to `hello-springboot-service/master` or run the app workflow manually.

Expected chain:

```text
GitHub Actions success
ECR image pushed
GitOps values-dev.yaml updated
Argo CD syncs hello-springboot
ALB becomes available
```

Verify:

```bash
kubectl get pods -n hello
kubectl get ingress -n hello
curl "http://<alb-dns>/hello"
```

## 8. Cleanup

Delete ingress first:

```bash
kubectl delete ingress -n hello --all
```

Destroy in reverse order:

```bash
cd infra/live/dev/argocd-bootstrap && tofu destroy
cd ../eks && tofu destroy
cd ../ecr && tofu destroy
cd ../network && tofu destroy
```

Keep `bootstrap/state-backend` if you want to preserve state history.
