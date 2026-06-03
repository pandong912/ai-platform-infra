# Argo Rollouts PoC

This PoC installs Argo Rollouts and converts `hello-web` from a Kubernetes
Deployment to an Argo Rollout.

Provider services remain standard Deployments:

- `hello-grpc`
- `hello-dubbo`

## 1. Commit GitOps Changes

```bash
git checkout -b add-argo-rollouts
git add gitops/platform/argo-rollouts \
  gitops/clusters/dev/apps/argo-rollouts.yaml \
  gitops/apps/hello-springboot/templates/deployment.yaml \
  gitops/apps/hello-springboot/values-dev.yaml \
  gitops/apps/hello-springboot/values.yaml \
  docs/argo-rollouts-poc.md
git commit -m "Add Argo Rollouts PoC"
git push origin add-argo-rollouts
```

Open a PR and merge into `master`.

## 2. Check Controller

```bash
kubectl get applications -n argocd | grep argo-rollouts
kubectl get pods -n argo-rollouts
```

## 3. Handle First Migration if Needed

The existing `hello-web` may still be a Deployment. If Argo CD reports a kind
conflict when replacing it with a Rollout, delete the old Deployment once:

```bash
kubectl delete deployment -n hello hello-web
```

Then refresh Argo CD:

```bash
kubectl -n argocd annotate application hello-springboot \
  argocd.argoproj.io/refresh=hard \
  --overwrite
```

## 4. Check Rollout

```bash
kubectl get rollout -n hello
kubectl describe rollout -n hello hello-web
```

If you have the kubectl plugin:

```bash
kubectl argo rollouts get rollout hello-web -n hello --watch
```

## 5. Promote or Abort

Promote:

```bash
kubectl argo rollouts promote hello-web -n hello
```

Abort:

```bash
kubectl argo rollouts abort hello-web -n hello
```

Undo:

```bash
kubectl argo rollouts undo hello-web -n hello
```

## 6. Dashboard

```bash
kubectl -n argo-rollouts port-forward svc/argo-rollouts-dashboard 31000:3100
```

Open:

```text
http://localhost:31000
```

## 7. Current Canary Strategy

The PoC uses simple replica-weighted canary steps:

```yaml
strategy:
  canary:
    steps:
      - setWeight: 50
      - pause:
          duration: 30s
```

This does not yet do traffic splitting at Kong/ALB level. It validates Rollout
lifecycle first. Later you can add Kong/Ingress traffic routing or metric-based
AnalysisTemplates.

## 8. Verify Service

```bash
KONG_ALB="$(kubectl get ingress -n kong kong-alb -o jsonpath='{.status.loadBalancer.ingress[0].hostname}')"
curl "http://${KONG_ALB}/hello"
```
