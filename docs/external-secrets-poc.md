# External Secrets Operator with AWS Secrets Manager

This PoC installs External Secrets Operator (ESO) and syncs selected AWS Secrets
Manager secrets into Kubernetes Secrets.

## Secret Naming

ESO is scoped to read secrets under:

```text
ai-video-platform/dev/*
```

Expected AWS Secrets Manager names:

```text
ai-video-platform/dev/logto
ai-video-platform/dev/temporal
ai-video-platform/dev/dify
ai-video-platform/dev/grafana
```

## 1. Create IRSA Role

```bash
cd infra/live/dev/external-secrets
cp backend.tf.example backend.tf
cp terraform.tfvars.example terraform.tfvars
tofu init
tofu plan
tofu apply
```

Collect:

```bash
tofu output -raw external_secrets_role_arn
```

## 2. Create AWS Secrets

Create or update the secrets in AWS Secrets Manager.

Logto:

```bash
aws secretsmanager create-secret \
  --region us-east-1 \
  --name ai-video-platform/dev/logto \
  --secret-string '{
    "DB_URL": "postgresql://logto:PASSWORD@HOST:5432/logto?sslmode=no-verify",
    "SECRET_VAULT_KEK": "REPLACE_WITH_BASE64_KEY"
  }'
```

Temporal:

```bash
aws secretsmanager create-secret \
  --region us-east-1 \
  --name ai-video-platform/dev/temporal \
  --secret-string '{
    "password": "REPLACE_WITH_TEMPORAL_DB_PASSWORD"
  }'
```

Dify:

```bash
aws secretsmanager create-secret \
  --region us-east-1 \
  --name ai-video-platform/dev/dify \
  --secret-string '{
    "DB_PASSWORD": "REPLACE_WITH_DIFY_DB_PASSWORD",
    "SECRET_KEY": "REPLACE_WITH_OPENSSL_RAND_BASE64_42"
  }'
```

Grafana:

```bash
aws secretsmanager create-secret \
  --region us-east-1 \
  --name ai-video-platform/dev/grafana \
  --secret-string '{
    "admin-user": "admin",
    "admin-password": "REPLACE_WITH_GRAFANA_PASSWORD"
  }'
```

If a secret already exists, use:

```bash
aws secretsmanager put-secret-value \
  --region us-east-1 \
  --secret-id ai-video-platform/dev/logto \
  --secret-string '{...}'
```

## 3. Replace ESO Role Placeholder

Edit:

```text
gitops/platform/external-secrets/values-dev.yaml
gitops/platform/external-secrets/values.yaml
```

Replace:

```text
REPLACE_WITH_EXTERNAL_SECRETS_ROLE_ARN
```

with:

```bash
cd infra/live/dev/external-secrets
tofu output -raw external_secrets_role_arn
```

## 4. Commit GitOps Changes

```bash
git checkout -b add-external-secrets
git add infra/live/dev/external-secrets \
  gitops/platform/external-secrets \
  gitops/clusters/dev/apps/external-secrets.yaml \
  docs/external-secrets-poc.md
git commit -m "Add External Secrets Operator PoC"
git push origin add-external-secrets
```

Open a PR and merge into `master`.

## 5. Verify ESO

```bash
kubectl get applications -n argocd | grep external-secrets
kubectl get pods -n external-secrets
kubectl get clustersecretstore aws-secrets-manager
```

Check synced secrets:

```bash
kubectl get externalsecrets -A
kubectl get secret -n logto logto-env
kubectl get secret -n temporal temporal-db
kubectl get secret -n dify dify-env
kubectl get secret -n monitoring grafana-admin
```

## 6. Migration Notes

This PoC creates Kubernetes Secrets with the same names currently expected by
apps. Existing manually created Secrets may need to be deleted or replaced so
ESO can own them:

```bash
kubectl -n logto delete secret logto-env
kubectl -n temporal delete secret temporal-db
kubectl -n dify delete secret dify-env
kubectl -n monitoring delete secret grafana-admin
```

Then wait for ESO to recreate them:

```bash
kubectl get externalsecrets -A
```

Restart workloads only if they do not pick up secret changes automatically.

## 7. Production Hardening

- Use separate secret prefixes for dev/staging/prod.
- Restrict IAM role to exact secret ARNs.
- Enable AWS CloudTrail auditing.
- Rotate secrets with AWS Secrets Manager rotation where possible.
- Add alerts for ExternalSecret sync failures.
- Use External Secrets for all app credentials before production.
