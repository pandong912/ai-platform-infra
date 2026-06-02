# Kong Gateway PoC

This PoC deploys Kong Gateway OSS and Kong Ingress Controller to the existing
EKS cluster.

Traffic path:

```text
Internet
  -> AWS ALB
  -> Kong proxy
  -> hello-springboot service
```

Kong runs in DB-less mode. The Admin API and Manager are disabled.

## 1. Commit GitOps Changes

```bash
git checkout -b add-kong-gateway-poc
git add gitops/platform/kong \
  gitops/clusters/dev/apps/kong.yaml \
  gitops/clusters/dev/apps/hello-springboot.yaml \
  gitops/apps/hello-springboot \
  docs/kong-gateway-poc.md
git commit -m "Add Kong Gateway PoC"
git push origin add-kong-gateway-poc
```

Open a PR and merge it into `master`.

## 2. Check Argo CD

```bash
kubectl get applications -n argocd
```

Expected:

```text
kong               Synced   Healthy
hello-springboot   Synced   Healthy
```

If `hello-springboot` syncs before Kong CRDs exist, refresh it after Kong is
healthy:

```bash
kubectl -n argocd annotate application hello-springboot \
  argocd.argoproj.io/refresh=hard \
  --overwrite
```

## 3. Check Kong

```bash
kubectl get pods,svc,ingress -n kong
```

Expected:

- `kong` pods are Running.
- `kong-proxy` service exists.
- `kong-alb` ingress has an ALB hostname.

Get the Kong ALB hostname:

```bash
kubectl get ingress -n kong kong-alb \
  -o jsonpath='{.status.loadBalancer.ingress[0].hostname}'; echo
```

## 4. Test Hello Through Kong

```bash
KONG_ALB="$(kubectl get ingress -n kong kong-alb -o jsonpath='{.status.loadBalancer.ingress[0].hostname}')"
curl "http://${KONG_ALB}/hello"
```

Expected:

```text
hello from spring boot on eks
```

The direct hello ALB still exists for comparison. This PoC does not remove it.

## 5. Test Rate Limiting

The hello route has a local Kong rate limit:

```text
30 requests / minute
```

Run:

```bash
for i in $(seq 1 35); do
  code="$(curl -s -o /dev/null -w '%{http_code}' "http://${KONG_ALB}/hello")"
  echo "$i $code"
done
```

After the limit is exceeded, Kong should return:

```text
429
```

PoC uses `policy: local`, so counters are per Kong pod. For production-grade
global rate limiting across replicas, use Redis-backed rate limiting.

## 6. Next Steps

- Add Logto JWT/OIDC authentication in Kong.
- Move direct service ALBs behind Kong-only routing.
- Add HTTPS with ACM and DNS.
- Add Kong metrics dashboards in Grafana.
- Use Redis-backed rate limiting if Kong has multiple replicas.
