# OpenSearch Logging PoC

This PoC ships EKS container logs to Amazon OpenSearch Service.

Pipeline:

```text
Pods stdout/stderr
  -> containerd log files
  -> aws-for-fluent-bit DaemonSet
  -> Amazon OpenSearch Service
  -> OpenSearch Dashboards / OpenSearch API
```

## 1. Create OpenSearch and Fluent Bit IAM

```bash
cd infra/live/dev/opensearch-logs
cp backend.tf.example backend.tf
cp terraform.tfvars.example terraform.tfvars
```

Edit `terraform.tfvars` if needed:

```hcl
state_bucket_name = "ai-video-platform"
domain_name       = "ai-video-logs-dev"
```

Apply:

```bash
tofu init
tofu plan
tofu apply
```

Collect outputs:

```bash
tofu output -raw opensearch_endpoint
tofu output -raw fluent_bit_role_arn
```

OpenSearch domain creation can take 10-20 minutes.

## 2. Replace Fluent Bit Values

Edit:

```text
gitops/platform/aws-for-fluent-bit/values-dev.yaml
gitops/platform/aws-for-fluent-bit/values.yaml
```

Replace:

```text
REPLACE_WITH_OPENSEARCH_ENDPOINT
REPLACE_WITH_FLUENT_BIT_ROLE_ARN
```

Use the endpoint without `https://`.

## 3. Commit GitOps Changes

```bash
git checkout -b add-opensearch-logging
git add infra/live/dev/opensearch-logs \
  gitops/platform/aws-for-fluent-bit \
  gitops/clusters/dev/apps/aws-for-fluent-bit.yaml \
  gitops/apps/hello-springboot/templates \
  docs/opensearch-logging-poc.md
git commit -m "Add OpenSearch logging PoC"
git push origin add-opensearch-logging
```

Open a PR and merge into `master`.

## 4. Check Fluent Bit

```bash
kubectl get applications -n argocd
kubectl get pods -n logging
kubectl logs -n logging daemonset/aws-for-fluent-bit --tail=100
```

## 5. Generate Logs

```bash
KONG_ALB="$(kubectl get ingress -n kong kong-alb -o jsonpath='{.status.loadBalancer.ingress[0].hostname}')"
curl "http://${KONG_ALB}/hello"
curl "http://${KONG_ALB}/hello/aggregate?name=logging"
```

## 6. Query OpenSearch

From a machine with AWS credentials:

```bash
OPENSEARCH_ENDPOINT="$(cd infra/live/dev/opensearch-logs && tofu output -raw opensearch_endpoint)"
curl -s "https://${OPENSEARCH_ENDPOINT}/_cat/indices?v"
```

Expected index pattern:

```text
eks-dev-YYYY.MM.DD
```

For VPC-only domains, access may require running the query from inside the VPC
or through a bastion/VPN/port-forwarding setup.

## 7. OpenSearch Dashboards

Get the dashboard endpoint:

```bash
cd infra/live/dev/opensearch-logs
tofu output opensearch_dashboard_endpoint
```

Because this PoC domain is VPC-only, access requires network connectivity into
the VPC. For production, use SSO/IAM-authenticated access and avoid public
anonymous dashboards.

## 8. Application JSON Logs

The Spring Boot demo services output JSON logs to stdout with fields:

```json
{
  "service": "hello-web",
  "env": "dev",
  "level": "INFO",
  "logger_name": "...",
  "message": "..."
}
```

The Kubernetes metadata added by Fluent Bit includes namespace, pod, container,
labels, and node information.

## 9. Production Hardening

- Use Firehose between Fluent Bit and OpenSearch for buffering and S3 backup.
- Configure OpenSearch Index State Management.
- Separate indices for application, platform, gateway, and audit logs.
- Use structured JSON logging for all services.
- Add traceId/spanId through OpenTelemetry.
- Avoid DEBUG logs by default.
- Define retention policies before increasing log volume.
