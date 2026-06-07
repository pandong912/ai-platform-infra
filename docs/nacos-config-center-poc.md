# Nacos Config Center PoC

This PoC deploys Nacos to the EKS dev cluster through Argo CD.

The current dev deployment uses Nacos standalone mode with an external RDS
MySQL database. It exposes the Nacos console through Kong at `/nacos` for dev
access. This is closer to a real configuration center than embedded storage,
but it is still not a production topology.

## Topology

```text
Argo CD root-dev
  -> nacos Application
    -> nacos namespace
      -> ExternalSecret/nacos-env
      -> Deployment/nacos
      -> Service/nacos
      -> Ingress/nacos-kong

OpenTofu
  -> RDS MySQL
  -> AWS Secrets Manager ai-video-platform/dev/nacos
```

## 1. Create External Dependencies

Create the RDS MySQL instance and AWS Secrets Manager secret:

```bash
cd infra/live/dev/nacos-deps
cp backend.tf.example backend.tf
cp terraform.tfvars.example terraform.tfvars
tofu init
tofu plan
tofu apply
```

Get the RDS endpoint and secret name:

```bash
tofu output db_endpoint
tofu output secret_name
```

The secret is consumed by External Secrets Operator and projected as the
Kubernetes secret `nacos-env` in the `nacos` namespace.

## 2. Deploy

Commit and merge:

```bash
git add infra/live/dev/nacos-deps \
  gitops/platform/nacos \
  gitops/clusters/dev/apps/nacos.yaml \
  docs/nacos-config-center-poc.md
git commit -m "Add Nacos config center with RDS MySQL"
git push
```

After Argo CD syncs:

```bash
kubectl get application -n argocd nacos
kubectl get externalsecret,secret,pods,svc,ingress -n nacos
```

Wait for rollout:

```bash
kubectl rollout status deployment/nacos -n nacos --timeout=300s
```

## 3. Validate

Internal health check:

```bash
kubectl -n nacos port-forward svc/nacos 8848:8848
```

Open:

```text
http://localhost:8848/nacos
```

Kong entry:

```bash
KONG_ALB="$(kubectl get ingress -n kong kong-alb -o jsonpath='{.status.loadBalancer.ingress[0].hostname}')"
open "http://${KONG_ALB}/nacos"
```

Nacos auth is enabled. For dev, the default console user is typically:

```text
nacos / nacos
```

Health:

```bash
curl -sS http://localhost:8848/nacos/v1/console/health/readiness
curl -sS http://localhost:8848/nacos/v1/console/health/liveness
```

## 4. Database Schema

Nacos requires its MySQL schema to exist. If the pod logs show missing table
errors, import the Nacos MySQL schema into the RDS database before retrying.

Inspect logs:

```bash
kubectl logs -n nacos deployment/nacos --tail=120
```

You can retrieve database connection values from the Kubernetes secret:

```bash
kubectl -n nacos get secret nacos-env \
  -o jsonpath='{.data.MYSQL_SERVICE_HOST}' | base64 --decode; echo
```

For production, manage schema initialization explicitly in migration tooling or
an audited runbook.

## Kubernetes Service DNS

Applications in the cluster can use:

```text
nacos.nacos.svc.cluster.local:8848
```

For Spring Cloud Alibaba Nacos Config:

```yaml
spring:
  cloud:
    nacos:
      config:
        server-addr: nacos.nacos.svc.cluster.local:8848
```

## Production Notes

Before using Nacos as a durable platform configuration center, replace this
standalone dev topology with:

- External MySQL-compatible persistence, preferably RDS MySQL or Aurora MySQL.
- Multiple Nacos replicas.
- Authentication enabled.
- Private-only access by default, with controlled admin access.
- Backups and restore testing for the persistence layer.

