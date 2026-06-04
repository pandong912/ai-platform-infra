# Apollo on EKS

This chart deploys a production-minimal Apollo Config Center stack on EKS:

- Apollo Config Service
- Apollo Admin Service
- Apollo Portal
- Internal ALB ingress for Portal
- HPA and PodDisruptionBudget for each component
- External MySQL/RDS only, with database passwords supplied by an existing Secret

The chart does not deploy a standalone Eureka cluster. Apollo still exposes and
uses an Eureka-compatible endpoint internally, but EKS service discovery is
handled by Kubernetes Service DNS.

## Required Prerequisites

1. Create an Amazon RDS MySQL instance, preferably Multi-AZ for shared or production environments.
2. Create and initialize the Apollo databases from the SQL scripts that match the Apollo image version:
   - `ApolloPortalDB`
   - `ApolloConfigDB`
3. Create the runtime database Secret before Argo CD syncs this application:

```bash
kubectl create namespace apollo
kubectl -n apollo create secret generic apollo-db \
  --from-literal=config-db-password='<config-db-password>' \
  --from-literal=portal-db-password='<portal-db-password>'
```

4. Replace `REPLACE_WITH_APOLLO_RDS_ENDPOINT` in `values-dev.yaml` with the RDS writer endpoint.
5. Replace `apollo.dev.internal` with the internal DNS name that should route to Apollo Portal.

## Internal Endpoints

Applications running in the cluster should use Config Service through the cluster DNS name:

```text
http://apollo-configservice.apollo.svc.cluster.local:8080
```

Portal is exposed through an internal ALB. It should not be made internet-facing unless it is protected by company SSO, VPN, or a zero-trust access layer.

## Service Discovery Model

Use Kubernetes Service DNS as the platform discovery layer:

- `apollo-configservice.apollo.svc.cluster.local` for Apollo clients and Portal meta.
- `apollo-adminservice.apollo.svc.cluster.local` only for in-cluster diagnostics or future internal integrations.

The `internalDiscovery.eurekaUrl` value exists only because upstream Apollo
components expect an Eureka-compatible registration endpoint. Keep it pointed at
Apollo Config Service; do not introduce a separate Eureka deployment in EKS.

## Spring Boot Client Example

Set the application identity and Apollo meta endpoint:

```properties
app.id=video-platform-service
apollo.bootstrap.enabled=true
apollo.bootstrap.namespaces=application
apollo.meta=http://apollo-configservice.apollo.svc.cluster.local:8080
```

For containerized workloads, prefer environment-specific injection:

```yaml
env:
  - name: APP_ID
    value: video-platform-service
  - name: APOLLO_META
    value: http://apollo-configservice.apollo.svc.cluster.local:8080
  - name: ENV
    value: DEV
```

## Verification

```bash
argocd app get apollo
kubectl -n apollo get pods,svc,ingress,hpa,pdb
kubectl -n apollo logs deploy/apollo-configservice
kubectl -n apollo logs deploy/apollo-adminservice
kubectl -n apollo logs deploy/apollo-portal
```

After Portal is reachable, create a test app and namespace, change a property, and verify a Spring Boot client receives the new value without a restart.

## Operating Boundaries

Use Apollo for business configuration, feature flags, rollout parameters, degradation switches, and AI video platform runtime tuning. Keep Dubbo registry, metadata, and service discovery concerns in Nacos or another service registry if needed. Do not manage the same business configuration in both Apollo and Nacos.
