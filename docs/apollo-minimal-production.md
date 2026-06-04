# Apollo Minimal Production Integration

This runbook adds Apollo Config Center to the EKS GitOps stack as the primary business configuration platform.

## Scope

The first production-usable integration includes:

- Apollo Portal for configuration management, release, rollback, and audit workflows.
- Apollo Config Service for client-side configuration reads and long polling.
- Apollo Admin Service for configuration publishing.
- External Amazon RDS MySQL for persistent data.
- Internal ALB access for Portal.
- HPA and PDB for all Apollo services.
- Kubernetes Secret based database credentials.
- Kubernetes Service DNS as the EKS-facing service discovery layer.

It intentionally does not include internet-facing access, SSO, approval workflow integration, or multi-environment production databases yet.

## Architecture

```text
Developers / Platform Team
        |
        v
Internal ALB
        |
        v
Apollo Portal
        |
        v
Apollo Config Service <---- Apollo Admin Service
        |
        v
Amazon RDS MySQL
  - ApolloPortalDB
  - ApolloConfigDB
```

Applications in EKS talk to Config Service through Kubernetes DNS:

```text
http://apollo-configservice.apollo.svc.cluster.local:8080
```

Apollo's upstream components still expect an Eureka-compatible internal
registration endpoint. In this deployment, that endpoint is provided by Apollo
Config Service itself and reached through Kubernetes Service DNS. Do not deploy
a standalone Eureka cluster for Apollo on EKS.

## EKS Service Discovery Model

For EKS, keep service discovery split this way:

- Kubernetes Service DNS handles stable addressing between Apollo components and application clients.
- Apollo's internal Eureka-compatible endpoint remains an implementation detail for Config Service, Admin Service, and Portal compatibility.
- Application workloads should never depend on Eureka for Apollo. They should use `apollo.meta` pointing to the Config Service Kubernetes Service.

This is the simpler EKS-native model: no independent Eureka StatefulSet, no Eureka persistence, no Eureka ingress, and no separate registry operations.

## Prerequisites

1. Create an RDS MySQL instance.

   Recommended baseline:

   - MySQL 8.0
   - Multi-AZ for shared or production environments
   - Private subnets only
   - Security group allowing inbound 3306 from EKS worker node or pod security groups
   - Automated backups enabled

2. Create the Apollo database user.

   ```sql
   CREATE USER 'apollo'@'%' IDENTIFIED BY '<password>';
   GRANT ALL PRIVILEGES ON ApolloPortalDB.* TO 'apollo'@'%';
   GRANT ALL PRIVILEGES ON ApolloConfigDB.* TO 'apollo'@'%';
   FLUSH PRIVILEGES;
   ```

3. Initialize the databases with the SQL scripts that match the Apollo image tag in `gitops/apps/apollo/values.yaml`.

   The chart currently defaults to Apollo `2.2.0`. Use the matching Apollo release SQL for:

   - `ApolloPortalDB`
   - `ApolloConfigDB`

4. Create the Kubernetes Secret:

   ```bash
   kubectl create namespace apollo
   kubectl -n apollo create secret generic apollo-db \
     --from-literal=config-db-password='<config-db-password>' \
     --from-literal=portal-db-password='<portal-db-password>'
   ```

5. Update `gitops/apps/apollo/values-dev.yaml`:

   - Replace `REPLACE_WITH_APOLLO_RDS_ENDPOINT`.
   - Replace `apollo.dev.internal` with the internal DNS name for Portal.

## GitOps Deployment

Apollo is registered as an Argo CD child application:

```text
gitops/clusters/dev/apps/apollo.yaml
```

The root app already points at:

```text
gitops/clusters/dev/apps
```

After the changes are pushed, Argo CD should discover and sync the Apollo application automatically.

Manual verification:

```bash
argocd app get apollo
argocd app sync apollo
kubectl -n apollo get pods
kubectl -n apollo get svc
kubectl -n apollo get ingress
kubectl -n apollo get hpa,pdb
```

## Runtime Verification

1. Verify Config Service starts and connects to RDS:

   ```bash
   kubectl -n apollo logs deploy/apollo-configservice
   ```

2. Verify Admin Service registers with Config Service:

   ```bash
   kubectl -n apollo logs deploy/apollo-adminservice
   ```

3. Verify Portal can discover the dev environment:

   ```bash
   kubectl -n apollo logs deploy/apollo-portal
   ```

4. Open the internal Portal hostname and create:

   - App ID: `video-platform-service`
   - Namespace: `application`
   - Key: `feature.test-switch`
   - Value: `true`

5. Connect a Spring Boot service and verify it receives a config change without restarting.

## Spring Boot Client Baseline

Application properties:

```properties
app.id=video-platform-service
apollo.bootstrap.enabled=true
apollo.bootstrap.namespaces=application
apollo.meta=http://apollo-configservice.apollo.svc.cluster.local:8080
```

Kubernetes environment variables:

```yaml
env:
  - name: APP_ID
    value: video-platform-service
  - name: APOLLO_META
    value: http://apollo-configservice.apollo.svc.cluster.local:8080
  - name: ENV
    value: DEV
```

For ordinary scalar configuration, Apollo Spring integration is usually enough. For thread pools, rate limiters, Dubbo runtime parameters, model routing, or inference controls, use explicit change listeners and update the runtime object intentionally.

## Production Hardening Backlog

- Put Portal behind SSO/OIDC, VPN, or zero-trust access.
- Add external-dns and ACM TLS for the internal Portal hostname.
- Move database credentials from manual Secrets to External Secrets Manager.
- Split dev, staging, and prod Apollo ConfigDB instances.
- Add audit log retention and backup restore drills.
- Add Prometheus scraping if Apollo runtime metrics are enabled.
- Add NetworkPolicy once the cluster network policy engine is installed.
- Add RDS failover and EKS node interruption tests to the release checklist.

## Boundary With Dubbo Infrastructure

Apollo should own business configuration, feature flags, rollout parameters, degradation switches, and AI video platform runtime tuning. Nacos can still be used for Dubbo registry, metadata, and service discovery. Do not put the same configuration domain in both systems.
