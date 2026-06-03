# Temporal on EKS PoC

This PoC deploys Temporal Server and Temporal Web on EKS with RDS PostgreSQL.

Temporal components:

- frontend
- history
- matching
- worker
- admintools
- web

Persistence:

- `temporal` database for the default store
- `temporal_visibility` database for visibility

Important: `numHistoryShards` is set to `128` for this PoC and should not be
changed after initial deployment.

## 1. Create RDS PostgreSQL

```bash
cd infra/live/dev/temporal-deps
cp backend.tf.example backend.tf
cp terraform.tfvars.example terraform.tfvars
```

Edit `terraform.tfvars`:

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

Collect endpoint:

```bash
tofu output -raw db_endpoint
```

## 2. Create Visibility Database

Temporal needs both `temporal` and `temporal_visibility`.

```bash
kubectl run -n default temporal-psql-client --rm -it \
  --image=postgres:16-alpine \
  --restart=Never \
  --env PGPASSWORD='<DB_PASSWORD>' \
  -- psql \
    -h '<RDS_ENDPOINT>' \
    -U temporal \
    -d temporal \
    -c 'CREATE DATABASE temporal_visibility;'
```

If it already exists, PostgreSQL will return an error. That is safe to ignore if
you are re-running the setup.

## 3. Create Temporal DB Secret

```bash
kubectl create namespace temporal --dry-run=client -o yaml | kubectl apply -f -

kubectl -n temporal create secret generic temporal-db \
  --from-literal=password='<DB_PASSWORD>'
```

Do not commit this secret into Git. Production should use AWS Secrets Manager
and External Secrets.

## 4. Replace Values Placeholder

Edit:

```text
gitops/apps/temporal/values-dev.yaml
gitops/apps/temporal/values.yaml
```

Replace:

```text
REPLACE_WITH_TEMPORAL_RDS_ENDPOINT
```

with the RDS endpoint from `tofu output -raw db_endpoint`.

## 5. Commit GitOps Changes

```bash
git checkout -b add-temporal-poc
git add infra/live/dev/temporal-deps gitops/apps/temporal gitops/clusters/dev/apps/temporal.yaml docs/temporal-poc.md
git commit -m "Add Temporal PoC deployment"
git push origin add-temporal-poc
```

Open a PR and merge into `master`.

## 6. Check Argo CD

```bash
kubectl get applications -n argocd
kubectl get pods -n temporal
```

Expected:

```text
temporal   Synced   Healthy
```

The first deployment creates and updates the SQL schema through chart jobs, so
startup may take several minutes.

## 7. Access Temporal Web

```bash
kubectl -n temporal port-forward svc/temporal-web 8088:8080
```

Open:

```text
http://localhost:8088
```

## 8. Access Temporal Frontend for SDK/CLI

```bash
kubectl -n temporal port-forward svc/temporal-frontend 7233:7233
```

Then use:

```bash
temporal operator namespace list --address localhost:7233
temporal workflow list --namespace default --address localhost:7233
```

## 9. Troubleshooting

Check schema jobs:

```bash
kubectl get jobs -n temporal
kubectl logs -n temporal job/<schema-job-name>
```

Check server pods:

```bash
kubectl get pods -n temporal
kubectl logs -n temporal deployment/temporal-frontend --tail=200
kubectl logs -n temporal deployment/temporal-history --tail=200
kubectl logs -n temporal deployment/temporal-matching --tail=200
kubectl logs -n temporal deployment/temporal-worker --tail=200
```

## 10. Production Hardening

- Use TLS for frontend and internode communication.
- Store DB password in AWS Secrets Manager.
- Use RDS Multi-AZ, backups, deletion protection, and password rotation.
- Expose Temporal Web through authenticated access only.
- Do not expose Temporal frontend publicly without mTLS/auth.
- Add SDK worker deployments separately from the Temporal cluster.
- Consider Temporal Cloud if you do not want to operate the cluster.
