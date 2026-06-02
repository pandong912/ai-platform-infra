# Logto OSS on EKS with RDS PostgreSQL

This PoC deploys Logto OSS on the existing EKS cluster and uses RDS PostgreSQL
for persistence.

Default access is through `kubectl port-forward`:

- Logto core: `http://localhost:3001`
- Logto admin console: `http://localhost:3002`

HTTP ALB ingress is included but disabled by default because Logto works best
with stable public hostnames for `ENDPOINT` and `ADMIN_ENDPOINT`.

## 1. Refresh EKS Outputs

The RDS module needs `node_security_group_id` from the EKS remote state.

```bash
cd infra/live/dev/eks
tofu apply
```

This should only update outputs if your cluster is already created.

## 2. Create RDS PostgreSQL

```bash
cd ../rds-logto
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

Get the endpoint:

```bash
tofu output -raw db_endpoint
```

## 3. Create Logto Kubernetes Secret

Generate a key encryption key:

```bash
openssl rand -base64 32
```

Create the namespace and secret:

```bash
kubectl create namespace logto --dry-run=client -o yaml | kubectl apply -f -

kubectl -n logto create secret generic logto-env \
  --from-literal=DB_URL='postgresql://logto:<DB_PASSWORD>@<RDS_ENDPOINT>:5432/logto' \
  --from-literal=SECRET_VAULT_KEK='<OPENSSL_OUTPUT>'
```

Do not commit this secret into Git.

## 4. Commit GitOps Changes

Commit the new Logto GitOps app:

```bash
git checkout -b add-logto-rds-poc
git add infra/live/dev/rds-logto gitops/clusters/dev/apps/logto.yaml gitops/apps/logto docs/logto-rds-http-poc.md infra/live/dev/eks/outputs.tf
git commit -m "Add Logto RDS HTTP PoC deployment"
git push origin add-logto-rds-poc
```

Open a PR and merge it into `master`.

Argo CD should create a new `logto` application:

```bash
kubectl get applications -n argocd
kubectl get pods -n logto
```

## 5. Access Logto

Port-forward the Logto service:

```bash
kubectl -n logto port-forward svc/logto 3001:3001 3002:3002
```

Open:

```text
http://localhost:3002
```

The core endpoint is:

```text
http://localhost:3001
```

## 6. Optional HTTP ALB

After you have two stable hostnames, update:

```text
gitops/apps/logto/values-dev.yaml
```

Example:

```yaml
logto:
  endpoint: http://logto.example.com
  adminEndpoint: http://admin.logto.example.com

ingress:
  enabled: true
  coreHost: logto.example.com
  adminHost: admin.logto.example.com
```

Commit and merge the GitOps change. Then create DNS CNAME records to the ALB
hostname from:

```bash
kubectl get ingress -n logto
```

## 7. Cleanup

Delete the Logto app first:

```bash
kubectl delete application logto -n argocd
kubectl delete namespace logto
```

Then destroy RDS:

```bash
cd infra/live/dev/rds-logto
tofu destroy
```
