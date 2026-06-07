# Ziyuan Qishuo Backend on EKS

This PoC deploys two backend modules from:

```text
https://github.com/xiongtao00/ziyuanqishuo.git
```

Services:

- `hanzi-content-system`
- `hanzi-management-system`

Database migration is intentionally manual in this PoC. It is not part of the
automated Argo CD deployment flow.

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
media_bucket_name = "REPLACE_WITH_GLOBALLY_UNIQUE_MEDIA_BUCKET"
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
tofu output -raw media_bucket_name
tofu output -raw media_access_key_id
tofu output -raw media_secret_access_key
tofu output -raw media_public_base_url
tofu output -raw media_cdn_domain_name
```

Media objects stay private in S3. Browser-readable media URLs are served by the
dedicated Hanzi media CloudFront distribution created in this module. Use
`media_public_base_url` as the management service `S3_PUBLIC_BASE_URL`.

Uploaded asset URLs are stored as:

```text
<media_public_base_url>/hanzi/media/<hanzi-id>/<type>/<yyyy>/<MM>/<dd>/raw/<file>
```

After apply, replace `S3_PUBLIC_BASE_URL` in
`gitops/apps/ziyuanqishuo/values-dev.yaml` with:

```bash
tofu output -raw media_public_base_url
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
  --from-literal=DB_PASSWORD='<DB_PASSWORD>' \
  --from-literal=JWT_SECRET='<REPLACE_WITH_LONG_RANDOM_SECRET>' \
  --from-literal=S3_ACCESS_KEY='<MEDIA_ACCESS_KEY_ID>' \
  --from-literal=S3_SECRET_KEY='<MEDIA_SECRET_ACCESS_KEY>'
```

The application uses the dedicated `S3StorageService` in the dev profile.
Non-sensitive S3 settings are provided by Helm values, while access keys are stored in this secret.

Production should migrate this secret to AWS Secrets Manager and External Secrets.

## 4. Run DB Migration Manually

After the database is reachable through the temporary DB tunnel, run Flyway from
your local machine:

```bash
cd /Users/pandong/IdeaProjects/ziyuanqishuo/ziyuanqishuo-backend

DB_URL='jdbc:postgresql://<DB_TUNNEL_OR_RDS_HOST>:5432/ziyuanqishuo' \
DB_USERNAME='ziyuanqishuo' \
DB_PASSWORD='<DB_PASSWORD>' \
mvn -pl hanzi-db-migration spring-boot:run
```

You can also run migration SQL manually in DataGrip if you need to inspect or
control each step. Apply files under:

```text
hanzi-db-migration/src/main/resources/db/migration
```

in version order.

## 5. Replace GitOps Image Placeholders

Edit:

```text
gitops/apps/ziyuanqishuo/values-dev.yaml
gitops/apps/ziyuanqishuo/values.yaml
```

Replace:

```text
REPLACE_WITH_ACCOUNT_ID
REPLACE_WITH_MEDIA_BUCKET
REPLACE_WITH_MEDIA_PUBLIC_BASE_URL
```

or wait for the `ziyuanqishuo` CI workflow to update the image repositories and
tags automatically.

## 6. Commit GitOps App

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

## 7. Build and Deploy Images

Merge the `ziyuanqishuo` repo workflow changes to `main`.

The workflow builds and pushes:

```text
ziyuanqishuo-content:content-<sha>
ziyuanqishuo-management:management-<sha>
```

It then creates a GitOps PR in `ai-platform-infra`.

Merge the generated GitOps PR.

## 8. Verify

```bash
kubectl get applications -n argocd | grep ziyuanqishuo
kubectl get pods -n ziyuanqishuo
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
- Media storage uses AWS S3 through the dedicated `S3StorageService`.
- DB migration is manual in this phase. Revisit automated migrations when you introduce staging/prod approval gates.
- The chart strips `/hanzi/content` and `/hanzi/management` prefixes before forwarding to services.
