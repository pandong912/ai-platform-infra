# Flyte on EKS PoC

This PoC deploys a Flyte OSS execution platform on EKS for video training Gold Dataset pipelines.

The deployment intentionally uses the stable Flyte 1 OSS Helm path:

- `flyte-binary` chart `v1.16.7`
- Spark Operator chart `2.5.1`
- KubeRay Operator chart `1.6.1`

Flyte2 is treated as a future backend migration target. The Dataset Spec and Planner example stays platform-neutral so the control plane does not depend on Flyte 1's Python DAG DSL.

## Components

- `infra/live/dev/flyte-deps`: RDS PostgreSQL, S3 artifact bucket, Secrets Manager secret, and IRSA roles.
- `gitops/apps/flyte`: Flyte Helm wrapper for EKS.
- `gitops/platform/spark-operator`: SparkApplication operator for Spark-backed tasks.
- `gitops/platform/kuberay-operator`: RayJob/RayCluster operator for Ray-backed tasks.
- `examples/flyte/dataset-builder`: Dataset Spec, Planner, and Flyte workflow example.

## 1. Create AWS Dependencies

```bash
cd infra/live/dev/flyte-deps
cp backend.tf.example backend.tf
cp terraform.tfvars.example terraform.tfvars
```

Edit `terraform.tfvars`:

```hcl
state_bucket_name = "ai-video-platform"
db_password       = "REPLACE_WITH_STRONG_PASSWORD"
flyte_bucket_name = "REPLACE_WITH_GLOBALLY_UNIQUE_FLYTE_BUCKET"
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
tofu output -raw s3_bucket_name
tofu output -raw backend_role_arn
tofu output -raw user_role_arn
tofu output -raw secret_name
```

## 2. Update Flyte Values

Edit `gitops/apps/flyte/values-dev.yaml` and replace:

```text
REPLACE_WITH_FLYTE_RDS_ENDPOINT
REPLACE_WITH_FLYTE_BUCKET
arn:aws:iam::REPLACE_WITH_ACCOUNT_ID:role/ai-video-platform-dev-flyte-backend
arn:aws:iam::REPLACE_WITH_ACCOUNT_ID:role/ai-video-platform-dev-flyte-user
```

Use the outputs from `flyte-deps`.

The chart expects External Secrets Operator and the `aws-secretsmanager` `ClusterSecretStore` to exist. The `ExternalSecret` reads `db_password` from the AWS Secrets Manager JSON created by OpenTofu and writes it to the Kubernetes secret `flyte-db`.

## 3. Sync GitOps Apps

The new Argo CD Applications are:

```text
gitops/clusters/dev/apps/spark-operator.yaml
gitops/clusters/dev/apps/kuberay-operator.yaml
gitops/clusters/dev/apps/flyte.yaml
```

Spark Operator and KubeRay Operator use sync-wave `10`; Flyte uses sync-wave `20`.

Check status:

```bash
kubectl get applications -n argocd spark-operator kuberay-operator flyte
kubectl get pods -n spark-operator
kubectl get pods -n kuberay-operator
kubectl get pods -n flyte
```

Expected:

```text
spark-operator    Synced   Healthy
kuberay-operator  Synced   Healthy
flyte             Synced   Healthy
```

## 4. Access Flyte

For the PoC, access Flyte by port-forward instead of public ingress:

```bash
kubectl -n flyte port-forward deploy/flyte 8088:8088 8089:8089
```

Open the console:

```text
http://localhost:8088/console
```

Create a local `~/.flyte/config.yaml` for CLI access:

```yaml
admin:
  endpoint: localhost:8089
  insecure: true
logger:
  show-source: true
  level: 0
```

Verify:

```bash
flytectl get projects
```

## 5. Run the Dataset Builder Example

Local dry run:

```bash
cd examples/flyte/dataset-builder
python -m venv .venv
source .venv/bin/activate
pip install -r requirements.txt
python -m dataset_builder.planner specs/video_caption_gold.yaml
python -m dataset_builder.workflow
```

Expected output is a local manifest path under `outputs/`.

Register to Flyte after building and pushing a workflow image:

```bash
docker build -t ghcr.io/REPLACE_WITH_ORG/dataset-builder:dev examples/flyte/dataset-builder
docker push ghcr.io/REPLACE_WITH_ORG/dataset-builder:dev

cd examples/flyte/dataset-builder
pyflyte register \
  --project dataset-platform \
  --domain development \
  --image ghcr.io/REPLACE_WITH_ORG/dataset-builder:dev \
  dataset_builder/workflow.py
```

Run:

```bash
pyflyte run --remote \
  --project dataset-platform \
  --domain development \
  dataset_builder/workflow.py dataset_builder_workflow \
  --spec_path specs/video_caption_gold.yaml
```

## 6. Spark and Ray Validation

This PoC installs and configures the operators first. The Dataset Builder example marks `filter_candidates` and `dedup` as Spark steps and `sample` as a Ray step in the Planner output, but the included Flyte workflow keeps those steps as simple container tasks to avoid requiring a large cluster during bootstrap.

Minimal operator checks:

```bash
kubectl api-resources | grep -E 'sparkapplications|rayjobs|rayclusters'
kubectl get crd | grep -E 'sparkapplications|rayjobs|rayclusters'
```

When the cluster has enough capacity, replace the placeholder tasks with real `SparkApplication` or `RayJob` tasks and run one tiny job before enabling GPU or large worker pools.

## 7. Production Hardening

Before production:

- Enable TLS and proper `sslmode` for RDS.
- Add OIDC auth for Flyte Console/API.
- Expose HTTP and gRPC through an ingress path that supports gRPC correctly.
- Replace placeholder ARNs and bucket names with outputs managed by CI.
- Add backup and deletion protection for RDS and retention policy for S3.
- Add resource quotas for Flyte task namespaces.
- Add DataHub lineage emission after `publish`.

## Flyte2 Migration Boundary

The stable boundary is:

```text
Dataset Spec -> Planner -> Execution Backend Adapter
```

Today the adapter emits a Flyte 1 workflow. A future Flyte2 or Union adapter should consume the same Dataset Spec and Planner semantics, then emit the target platform's native workflow representation. Avoid storing Flyte-specific DSL objects as the source of truth.
