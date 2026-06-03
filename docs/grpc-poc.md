# gRPC PoC for hello-springboot

`hello-springboot-service` now deploys three services:

- `hello-web`: REST consumer on `8080`
- `hello-grpc`: gRPC provider on `9090`
- `hello-dubbo`: Dubbo Triple provider on `50051`

The Kubernetes Services expose:

```text
hello-web.hello.svc.cluster.local:8080
hello-grpc.hello.svc.cluster.local:9090
hello-dubbo.hello.svc.cluster.local:50051
```

## Test from Local Machine

After the updated image is deployed:

```bash
kubectl -n hello port-forward svc/hello-grpc 9090:9090
```

Then run:

```bash
grpcurl -plaintext \
  -d '{"name":"EKS"}' \
  localhost:9090 \
  hello.v1.HelloRpc/SayHello
```

Expected:

```json
{
  "message": "hello EKS from grpc on eks"
}
```

## Test from Inside the Cluster

```bash
kubectl run -n hello grpcurl --rm -it \
  --image=fullstorydev/grpcurl:latest \
  --restart=Never \
  -- -plaintext \
    -d '{"name":"cluster"}' \
    hello-grpc.hello.svc.cluster.local:9090 \
    hello.v1.HelloRpc/SayHello
```

## Test Through REST Aggregator

```bash
KONG_ALB="$(kubectl get ingress -n kong kong-alb -o jsonpath='{.status.loadBalancer.ingress[0].hostname}')"
curl "http://${KONG_ALB}/hello/grpc?name=EKS"
curl "http://${KONG_ALB}/hello/dubbo?name=EKS"
curl "http://${KONG_ALB}/hello/aggregate?name=EKS"
```

## Notes

- The gRPC service port is named `grpc`, which is important for future service mesh
  support.
- The Dubbo Triple service port is named `dubbo-tri`.
- This PoC keeps gRPC and Dubbo as internal east-west protocols.
- Kong is still used for REST north-south traffic.
- If you later expose gRPC through Kong or a service mesh, use explicit gRPC
  routes/listeners and keep HTTP/2 behavior in mind.
