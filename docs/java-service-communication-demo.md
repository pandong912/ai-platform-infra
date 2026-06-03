# Java Service Communication Demo

This demo splits `hello-springboot-service` into three independently deployed
Spring Boot services:

- `hello-web`: REST API and consumer of the internal RPC providers.
- `hello-grpc`: gRPC provider on port `9090`.
- `hello-dubbo`: Dubbo 3 Triple provider on port `50051`.

Traffic path:

```text
Kong ALB
  /hello           -> hello-web
  /hello/grpc      -> hello-web -> hello-grpc
  /hello/dubbo     -> hello-web -> hello-dubbo
  /hello/aggregate -> hello-web -> hello-grpc + hello-dubbo
```

Internal service addresses:

```text
hello-web.hello.svc.cluster.local:8080
hello-grpc.hello.svc.cluster.local:9090
hello-dubbo.hello.svc.cluster.local:50051
```

## Deployment Order

1. Merge the application repository PR that introduces the multi-module build.
2. Merge the infra repository PR that updates the Helm chart to three services.
3. Wait for the application CI workflow to create the GitOps image update PR.
4. Merge the GitOps image update PR.
5. Wait for Argo CD to sync `hello-springboot`.

## Verify Kubernetes Resources

```bash
kubectl get pods -n hello
kubectl get svc -n hello
```

Expected services:

```text
hello-web
hello-grpc
hello-dubbo
```

## Verify REST Through Kong

```bash
KONG_ALB="$(kubectl get ingress -n kong kong-alb -o jsonpath='{.status.loadBalancer.ingress[0].hostname}')"

curl "http://${KONG_ALB}/hello"
curl "http://${KONG_ALB}/hello/grpc?name=EKS"
curl "http://${KONG_ALB}/hello/dubbo?name=EKS"
curl "http://${KONG_ALB}/hello/aggregate?name=EKS"
```

Expected responses include:

```text
hello from spring boot web on eks
hello EKS from grpc on eks
hello EKS from dubbo triple on eks
```

## Verify gRPC Directly

```bash
kubectl run -n hello grpcurl --rm -it \
  --image=fullstorydev/grpcurl:latest \
  --restart=Never \
  -- -plaintext \
    -d '{"name":"cluster"}' \
    hello-grpc.hello.svc.cluster.local:9090 \
    hello.v1.HelloRpc/SayHello
```

Expected:

```json
{
  "message": "hello cluster from grpc on eks"
}
```

## Verify Dubbo

The simplest PoC verification is through the REST aggregator:

```bash
curl "http://${KONG_ALB}/hello/dubbo?name=EKS"
```

Expected:

```text
hello EKS from dubbo triple on eks
```

## Notes

- Dubbo uses Triple protocol with a direct URL:
  `tri://hello-dubbo.hello.svc.cluster.local:50051`.
- No Nacos, Zookeeper, or Dubbo control plane is used in this PoC.
- gRPC and Dubbo are internal east-west protocols.
- Kong only exposes the REST `hello-web` service.
