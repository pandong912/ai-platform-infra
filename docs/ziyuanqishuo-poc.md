# Ziyuan Qishuo Backend on EKS

This PoC deploys two backend modules from:

```text
https://github.com/xiongtao00/ziyuanqishuo.git
```

Services:

- `hanzi-content-system`
- `hanzi-management-system`

The database migration module runs as an Argo CD PreSync Job:

- `hanzi-db-migration`

## 1. Create AWS Dependencies

```bash
cd infra/live/dev/ziyuanqishuo
cp backend.tf.example backend.tf
cp terraform.tfvars.example terraform.tfvars
```

Edit:

```hcl
state_bucket_name = "ai-video-platform"
db_password       = "REPLACE_WITH_STRONG_PASSWORD"
```

Apply:

```bash
tofu init
tofu plan
tofu apply
```

Collect:

```bash
tofu output -raw db_endpoint
tofu output -raw github_ci_role_arn
tofu output repository_urls
```

## 2. Configure GitHub Actions

In `xiongtao00/ziyuanqishuo` repository, configure:

Secrets:

```text
AWS_ZIYUANQISHUO_CI_ROLE_ARN=<github_ci_role_arn>
GITOPS_REPO_TOKEN=<token with ai-platform-infra contents and PR write access>
```

Variables:

```text
AWS_REGION=us-east-1
GITOPS_REPO=pandong912/ai-platform-infra
```

The IAM trust policy allows only:

```text
repo:xiongtao00/ziyuanqishuo:ref:refs/heads/main
```

## 3. Create DB Secret

```bash
kubectl create namespace ziyuanqishuo --dry-run=client -o yaml | kubectl apply -f -

kubectl -n ziyuanqishuo create secret generic ziyuanqishuo-db \
  --from-literal=DB_URL='jdbc:postgresql://<RDS_ENDPOINT>:5432/ziyuanqishuo' \
  --from-literal=DB_USERNAME='ziyuanqishuo' \
  --from-literal=DB_PASSWORD='<DB_PASSWORD>'
```

Production should migrate this to AWS Secrets Manager and External Secrets.

## 4. Replace GitOps Image Placeholders

Edit:

```text
gitops/apps/ziyuanqishuo/values-dev.yaml
gitops/apps/ziyuanqishuo/values.yaml
```

Replace:

```text
REPLACE_WITH_ACCOUNT_ID
```

or wait for the `ziyuanqishuo` CI workflow to update the image repositories and
tags automatically.

## 5. Commit GitOps App

```bash
git checkout -b add-ziyuanqishuo-poc
git add infra/live/dev/ziyuanqishuo \
  gitops/apps/ziyuanqishuo \
  gitops/clusters/dev/apps/ziyuanqishuo.yaml \
  docs/ziyuanqishuo-poc.md
git commit -m "Add Ziyuan Qishuo backend PoC"
git push origin add-ziyuanqishuo-poc
```

Open a PR and merge into `master`.

## 6. Build and Deploy Images

Merge the `ziyuanqishuo` repo workflow changes to `main`.

The workflow builds and pushes:

```text
ziyuanqishuo-content:content-<sha>
ziyuanqishuo-management:management-<sha>
ziyuanqishuo-db-migration:migration-<sha>
```

It then creates a GitOps PR in `ai-platform-infra`.

Merge the generated GitOps PR.

## 7. Verify

```bash
kubectl get applications -n argocd | grep ziyuanqishuo
kubectl get pods -n ziyuanqishuo
kubectl get jobs -n ziyuanqishuo
```

Get Kong ALB:

```bash
KONG_ALB="$(kubectl get ingress -n kong kong-alb -o jsonpath='{.status.loadBalancer.ingress[0].hostname}')"
```

Content API example:

```bash
curl "http://${KONG_ALB}/hanzi/content/api/hanzi/<hanziId>/content"
```

Management API health:

```bash
curl "http://${KONG_ALB}/hanzi/management/actuator/health"
```

Swagger UI:

```text
http://<KONG_ALB>/hanzi/content/swagger-ui.html
http://<KONG_ALB>/hanzi/management/swagger-ui.html
```

## Notes

- The management module currently has auth bypass enabled in the PoC.
- Media storage defaults are not production-ready. Configure S3/OSS before real use.
- DB migration runs as a PreSync hook before app rollout.
- The chart strips `/hanzi/content` and `/hanzi/management` prefixes before forwarding to services.
