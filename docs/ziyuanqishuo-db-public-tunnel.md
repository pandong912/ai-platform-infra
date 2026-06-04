# Temporary Public DB Tunnel for Ziyuan Qishuo

This is a temporary development-only tunnel:

```text
DataGrip
  -> public AWS NLB:5432
  -> socat pod in EKS
  -> private RDS PostgreSQL:5432
```

RDS remains private. The NLB only allows:

```text
103.167.26.54/32
210.12.12.8/32
```

## Deploy

```bash
git checkout -b add-ziyuanqishuo-db-public-tunnel
git add gitops/apps/ziyuanqishuo-db-public-tunnel \
  gitops/clusters/dev/apps/ziyuanqishuo-db-public-tunnel.yaml \
  docs/ziyuanqishuo-db-public-tunnel.md
git commit -m "Add temporary Ziyuan Qishuo DB public tunnel"
git push origin add-ziyuanqishuo-db-public-tunnel
```

Open a PR and merge into `master`.

## Get NLB Hostname

```bash
kubectl get svc -n db-tunnel ziyuanqishuo-db-public-tunnel \
  -o jsonpath='{.status.loadBalancer.ingress[0].hostname}'; echo
```

## DataGrip

```text
Host: <NLB_HOSTNAME>
Port: 5432
Database: ziyuanqishuo
User: ziyuanqishuo
Password: <db_password>
```

## Verify

```bash
kubectl get pods,svc -n db-tunnel
kubectl logs -n db-tunnel deployment/ziyuanqishuo-db-public-tunnel --tail=100
```

## Cleanup

Delete the Argo CD application or remove the GitOps app from `master`:

```bash
kubectl delete application -n argocd ziyuanqishuo-db-public-tunnel
```

Then verify the NLB is gone:

```bash
kubectl get svc -n db-tunnel
```

Do not keep this tunnel longer than necessary.
