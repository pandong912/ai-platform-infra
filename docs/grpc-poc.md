# gRPC PoC for hello-springboot

`hello-springboot-service` exposes:

- REST: `8080`
- gRPC: `9090`

The Kubernetes Service exposes both ports:

```text
hello-springboot.hello.svc.cluster.local:8080
hello-springboot.hello.svc.cluster.local:9090
```

## Test from Local Machine

After the updated image is deployed:

```bash
kubectl -n hello port-forward svc/hello-springboot 9090:9090
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
    hello-springboot.hello.svc.cluster.local:9090 \
    hello.v1.HelloRpc/SayHello
```

## Notes

- The service port is named `grpc`, which is important for future service mesh
  support.
- This PoC keeps gRPC as an internal east-west protocol.
- Kong is still used for HTTP north-south traffic.
- If you later expose gRPC through Kong or a service mesh, use explicit gRPC
  routes/listeners and keep HTTP/2 behavior in mind.
