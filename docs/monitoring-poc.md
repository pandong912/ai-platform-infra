# Monitoring PoC with Prometheus and Grafana

This PoC installs `kube-prometheus-stack` through Argo CD.

It includes:

- Prometheus Operator
- Prometheus
- Grafana
- Alertmanager
- kube-state-metrics
- node-exporter
- default Kubernetes dashboards and rules

## 1. Commit GitOps Changes

Create a branch in `ai-platform-infra`:

```bash
git checkout -b add-monitoring-poc
git add gitops/platform/kube-prometheus-stack \
  gitops/clusters/dev/apps/kube-prometheus-stack.yaml \
  gitops/apps/hello-springboot \
  docs/monitoring-poc.md
git commit -m "Add Prometheus and Grafana monitoring PoC"
git push origin add-monitoring-poc
```

Open a PR and merge it into `master`.

## 2. Check Argo CD

```bash
kubectl get applications -n argocd
```

Expected:

```text
kube-prometheus-stack   Synced   Healthy
hello-springboot        Synced   Healthy
```

If `hello-springboot` syncs before the `ServiceMonitor` CRD exists, refresh it
after kube-prometheus-stack becomes healthy:

```bash
kubectl -n argocd annotate application hello-springboot \
  argocd.argoproj.io/refresh=hard \
  --overwrite
```

## 3. Check Monitoring Pods

```bash
kubectl get pods -n monitoring
```

## 4. Access Grafana

```bash
kubectl -n monitoring port-forward svc/kube-prometheus-stack-grafana 3000:80
```

Open:

```text
http://localhost:3000
```

PoC credentials:

```text
username: admin
password: admin123
```

For production, move the Grafana admin password to AWS Secrets Manager and
External Secrets.

## 5. Check Prometheus Targets

Port-forward Prometheus:

```bash
kubectl -n monitoring port-forward svc/kube-prometheus-stack-prometheus 9090:9090
```

Open:

```text
http://localhost:9090/targets
```

Search for `hello-springboot`. It should scrape:

```text
/actuator/prometheus
```

## 6. Useful PromQL

Spring Boot JVM/process metrics:

```promql
process_uptime_seconds
jvm_memory_used_bytes
http_server_requests_seconds_count
```

Kubernetes pod status:

```promql
kube_pod_container_status_restarts_total
kube_deployment_status_replicas_available
```

## 7. Next Steps

- Add Alertmanager routes.
- Add dashboards for Spring Boot and Argo CD.
- Add OpenTelemetry Collector for traces.
- Add Loki or another log backend if logs need to be centralized.
