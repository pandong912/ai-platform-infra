# Dify on EKS PoC

This PoC deploys Dify on EKS with AWS managed dependencies:

- RDS PostgreSQL for metadata and pgvector.
- ElastiCache Redis for cache and Celery.
- S3 for file and plugin storage.
- Kong Gateway for HTTP entry.

Traffic path:

```text
Kong ALB
  /hello -> hello-springboot
  /      -> Dify proxy
```

## 1. Create AWS Dependencies

```bash
cd infra/live/dev/dify-deps
cp backend.tf.example backend.tf
cp terraform.tfvars.example terraform.tfvars
```

Edit `terraform.tfvars`:

```hcl
state_bucket_name = "ai-video-platform"
db_password       = "REPLACE_WITH_STRONG_PASSWORD"
dify_bucket_name  = "REPLACE_WITH_GLOBALLY_UNIQUE_DIFY_BUCKET"
```

Apply:

```bash
tofu init
tofu plan
tofu apply
```

Collect outputs:

```bash
tofu output -raw db_endpoint
tofu output -raw redis_endpoint
tofu output -raw s3_bucket_name
tofu output -raw s3_role_arn
```

## 2. Initialize PostgreSQL for pgvector

Dify uses PostgreSQL plus pgvector in this PoC.

Run a temporary PostgreSQL client pod from inside the cluster:

```bash
kubectl run -n default psql-client --rm -it \
  --image=postgres:16-alpine \
  --restart=Never \
  --env PGPASSWORD='<DB_PASSWORD>' \
  -- psql \
    -h '<RDS_ENDPOINT>' \
    -U dify \
    -d dify \
    -c 'CREATE EXTENSION IF NOT EXISTS vector;'
```

If this command fails because the `vector` extension is unavailable in the
selected RDS engine version, switch the Dify values to use another vector store
such as external Weaviate or Qdrant.

## 3. Replace Dify Values Placeholders

Edit:

```text
gitops/apps/dify/values-dev.yaml
gitops/apps/dify/values.yaml
```

Replace:

```text
REPLACE_WITH_DIFY_S3_ROLE_ARN
REPLACE_WITH_OPENSSL_RAND_BASE64_42
REPLACE_WITH_DIFY_DB_PASSWORD
REPLACE_WITH_DIFY_RDS_ENDPOINT
REPLACE_WITH_DIFY_REDIS_ENDPOINT
REPLACE_WITH_DIFY_S3_BUCKET
```

Generate the app secret:

```bash
openssl rand -base64 42
```

PoC note: the community Helm chart stores some sensitive values in Helm values.
For production, move these values to AWS Secrets Manager and External Secrets.

## 4. Commit GitOps Changes

```bash
git checkout -b add-dify-poc
git add infra/live/dev/dify-deps gitops/apps/dify gitops/clusters/dev/apps/dify.yaml docs/dify-poc.md
git commit -m "Add Dify PoC deployment"
git push origin add-dify-poc
```

Open a PR and merge into `master`.

## 5. Check Argo CD

```bash
kubectl get applications -n argocd
kubectl get pods -n dify
```

Expected application:

```text
dify   Synced   Healthy
```

The first startup can take several minutes because Dify runs database
migrations and starts multiple components.

## 6. Access Dify Through Kong

Get the Kong ALB:

```bash
KONG_ALB="$(kubectl get ingress -n kong kong-alb -o jsonpath='{.status.loadBalancer.ingress[0].hostname}')"
echo "$KONG_ALB"
```

Open:

```text
http://<KONG_ALB>/
```

The hello service remains available through:

```text
http://<KONG_ALB>/hello
```

## 7. Troubleshooting

Check pods:

```bash
kubectl get pods -n dify
kubectl logs -n dify deployment/dify-api --tail=200
kubectl logs -n dify deployment/dify-worker --tail=200
kubectl logs -n dify deployment/dify-plugin-daemon --tail=200
```

Check Redis connectivity by running a temporary pod if needed:

```bash
kubectl run -n dify redis-client --rm -it \
  --image=redis:7-alpine \
  --restart=Never \
  -- redis-cli -h '<REDIS_ENDPOINT>' ping
```

## 8. Production Hardening

- Use a real domain and HTTPS.
- Store secrets in AWS Secrets Manager and sync through External Secrets.
- Use RDS Multi-AZ and deletion protection.
- Use ElastiCache replication group with auth and transit encryption.
- Use S3 IRSA only; avoid static S3 keys.
- Consider a managed vector database or a dedicated pgvector RDS instance.
- Add resource requests and HPA based on real traffic.
