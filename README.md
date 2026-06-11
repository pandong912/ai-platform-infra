# AI Platform Infra PoC

This repository contains the OpenTofu and GitOps configuration for the AWS EKS
CI/CD PoC.

Target flow:

```text
OpenTofu -> VPC/ECR/EKS/IAM/Argo CD bootstrap
GitHub Actions -> test/build/push image/update GitOps values
Argo CD -> sync GitOps state into EKS
AWS Load Balancer Controller -> expose /hello through ALB
```

## Repository Layout

```text
bootstrap/state-backend/          # S3 + DynamoDB + KMS for OpenTofu state
infra/live/dev/iam-github/        # GitHub Actions OIDC IAM roles
infra/live/dev/network/           # VPC and subnets
infra/live/dev/ecr/               # ECR repository for hello-springboot
infra/live/dev/codeartifact/      # CodeArtifact Maven repositories
infra/live/dev/eks/               # EKS cluster and controller IAM
infra/live/dev/argocd-bootstrap/  # Argo CD Helm bootstrap and root app
gitops/clusters/dev/apps/         # Argo CD child Applications
gitops/platform/                  # Platform Helm wrappers
gitops/apps/hello-springboot/     # Hello service Helm chart
```

## Nexus Repository Manager

Nexus can be deployed as a GitOps-managed platform component:

```text
gitops/platform/nexus
gitops/clusters/dev/apps/nexus.yaml
```

The default dev deployment uses:

- `StatefulSet` with one replica;
- a persistent `ReadWriteOnce` PVC for `/nexus-data`;
- `ClusterIP` service on port `8081` inside the cluster;
- Kong ingress on path `/nexus`, so external traffic reaches Nexus through Kong Gateway.

After Argo CD syncs Nexus and Kong, get the Kong ALB address:

```bash
kubectl -n kong get ingress kong-alb
```

Then open Nexus through Kong:

```text
http://<kong-alb-dns>/nexus
```

For local verification without using Kong, port-forward to a free local port such as `18081`:

```bash
kubectl -n nexus port-forward svc/nexus 18081:8081
open http://localhost:18081
```

Fetch the initial admin password:

```bash
kubectl -n nexus exec statefulset/nexus -- cat /nexus-data/admin.password
```

After the first login, create Maven repositories such as:

- `maven-releases`
- `maven-snapshots`
- `maven-public` as a group repository

For production, configure backup, retention, admin password rotation, repository permissions, and TLS/public access controls before exposing Nexus broadly.

## Defaults

- AWS region: `us-east-1`
- Environment: `dev`
- EKS cluster: `ai-video-poc-dev`
- Git branch: `master`
- ECR repository: `hello-springboot`

You can change these in each `terraform.tfvars` file.

## Branch Protection Note

Some GitHub private repositories do not enforce branch protection unless the
repository belongs to a GitHub Team or Enterprise organization. This PoC does
not depend on branch protection being enforced. Risk is reduced by:

- restricting AWS OIDC trust policies to this repository and `master`;
- making OpenTofu apply a manual `workflow_dispatch` job;
- requiring the `confirm=apply` input for apply;
- keeping production-grade approvals as a later Harness/GitHub Environment step.

## Step 1: Create Remote State Backend

Run once with local AWS admin credentials:

```bash
cd bootstrap/state-backend
cp terraform.tfvars.example terraform.tfvars
# edit state_bucket_name to a globally unique bucket
tofu init
tofu apply
```

Copy the output values into each `backend.tf.example`, then save as `backend.tf`
inside every root module under `infra/live/dev/*`.

## Step 2: Create GitHub OIDC Roles

```bash
cd infra/live/dev/iam-github
cp backend.tf.example backend.tf
cp terraform.tfvars.example terraform.tfvars
# edit github_owner and backend bucket
tofu init
tofu apply
```

Add these values to GitHub:

Infra repository secrets:

- `AWS_INFRA_PLAN_ROLE_ARN`
- `AWS_INFRA_APPLY_ROLE_ARN`

Infra repository variable:

- `AWS_REGION`

Application repository secrets:

- `AWS_APP_CI_ROLE_ARN`
- `GITOPS_REPO_TOKEN`

Application repository variables:

- `AWS_REGION`
- `GITOPS_REPO`, for example `your-user-or-org/ai-platform-infra`

## Step 3: Create Network, ECR, and CodeArtifact

```bash
cd infra/live/dev/network
cp backend.tf.example backend.tf
cp terraform.tfvars.example terraform.tfvars
tofu init
tofu apply

cd ../ecr
cp backend.tf.example backend.tf
cp terraform.tfvars.example terraform.tfvars
tofu init
tofu apply

cd ../codeartifact
cp backend.tf.example backend.tf
cp terraform.tfvars.example terraform.tfvars
tofu init
tofu apply
```

The `codeartifact` module creates:

- a CodeArtifact domain;
- an internal Maven repository for private jars;
- a Maven Central proxy repository used as an upstream.

Application CI can authenticate with GitHub OIDC and publish/read Maven packages:

```bash
export CODEARTIFACT_AUTH_TOKEN="$(aws codeartifact get-authorization-token \
  --domain ai-video-platform \
  --query authorizationToken \
  --output text)"

export CODEARTIFACT_MAVEN_URL="$(aws codeartifact get-repository-endpoint \
  --domain ai-video-platform \
  --repository maven-internal \
  --format maven \
  --query repositoryEndpoint \
  --output text)"
```

Use these values in Maven `settings.xml` or in GitHub Actions to run `mvn deploy`
for internal libraries and `mvn package` for services that consume them.

## Step 4: Create EKS

```bash
cd infra/live/dev/eks
cp backend.tf.example backend.tf
cp terraform.tfvars.example terraform.tfvars
# set state_bucket_name
tofu init
tofu apply
```

Configure local `kubectl`:

```bash
aws eks update-kubeconfig --region us-east-1 --name ai-video-poc-dev
kubectl get nodes
```

Copy `aws_load_balancer_controller_role_arn` from the output and replace:

```text
gitops/platform/aws-load-balancer-controller/values-dev.yaml
```

Also replace all occurrences of:

```text
https://github.com/REPLACE_WITH_GITHUB_USER_OR_ORG/ai-platform-infra.git
```

with your real GitHub repository URL.

## Step 5: Bootstrap Argo CD

```bash
cd infra/live/dev/argocd-bootstrap
cp backend.tf.example backend.tf
cp terraform.tfvars.example terraform.tfvars
# set state_bucket_name and gitops_repo_url
# if the GitOps repo is private, set gitops_repo_username/password
tofu init
tofu apply
```

Access Argo CD locally:

```bash
kubectl -n argocd port-forward svc/argocd-server 8080:80
kubectl -n argocd get secret argocd-initial-admin-secret \
  -o jsonpath='{.data.password}' | base64 -d
```

## Step 6: Deploy the Hello Service

After the `hello-springboot-service` workflow pushes an image, it updates:

```text
gitops/apps/hello-springboot/values-dev.yaml
```

Argo CD then syncs the application automatically.

Verify:

```bash
kubectl get pods -n hello
kubectl get ingress -n hello
curl "http://<alb-dns>/hello"
```

Expected response:

```text
hello from spring boot on eks
```

## Cost Cleanup

Delete application ingress before destroying the cluster so the ALB is cleaned up:

```bash
kubectl delete ingress -n hello --all
```

Then destroy in reverse order:

```bash
cd infra/live/dev/argocd-bootstrap && tofu destroy
cd ../eks && tofu destroy
cd ../ecr && tofu destroy
cd ../network && tofu destroy
```

Keep or destroy `bootstrap/state-backend` depending on whether you still need
the state history.