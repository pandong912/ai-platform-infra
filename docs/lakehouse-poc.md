# Iceberg Lakehouse Local PoC

This PoC builds a local lakehouse foundation for video training data with:

- MinIO as an S3-compatible object store.
- Apache Polaris as the Iceberg REST Catalog implementation.
- PostgreSQL as the persistent backend for Polaris metadata.
- Trino as the SQL query engine.
- Superset as an optional BI layer.
- DataHub as an optional metadata governance layer.

The implementation is intentionally isolated under `local/lakehouse/` and does
not touch the OpenTofu or Argo CD GitOps paths used for the EKS environment.

## 1. Architecture

```text
Trino SQL / ETL
  -> Trino
  -> Polaris Iceberg REST Catalog
  -> PostgreSQL catalog metadata

Trino
  -> MinIO S3 warehouse
  -> Iceberg metadata JSON and Parquet data files

Superset
  -> Trino

DataHub ingestion
  -> Trino metadata
  -> Superset metadata
```

Component responsibilities:

- `minio`: stores Iceberg table metadata files and Parquet data files.
- `minio-init`: creates the `warehouse` bucket.
- `postgresql`: persists Polaris metadata through its relational JDBC metastore.
- `polaris-bootstrap`: initializes the Polaris relational metastore and root
  credentials.
- `polaris`: exposes the Iceberg REST Catalog API on port `8181` and the health
  and metrics endpoint on port `8182`.
- `polaris-setup`: creates the `quickstart_catalog` catalog backed by MinIO and
  grants catalog content privileges to the local Trino principal.
- `trino`: exposes SQL on host port `8081` and connects to the `iceberg`
  catalog.
- `superset`: optional BI service exposed on host port `8088`.

The default Iceberg warehouse is:

```text
s3://warehouse
```

The default Polaris catalog name is:

```text
quickstart_catalog
```

## 2. Start the Core Stack

```bash
cd local/lakehouse
cp .env.example .env
docker compose up -d --build
```

Check containers:

```bash
docker compose ps
```

Expected local endpoints:

```text
MinIO API:       http://localhost:19000
MinIO Console:   http://localhost:19001
Polaris REST:    http://localhost:8181/api/catalog/v1/config
Polaris Health:  http://localhost:8182/q/health
Trino:           http://localhost:8081
PostgreSQL:      localhost:15432
```

Default local credentials:

```text
MinIO:      minioadmin / minioadmin
PostgreSQL: iceberg / iceberg
Polaris:    root / s3cr3t
```

These defaults are for local development only. If you change the MinIO
or Polaris credentials or bucket name in `.env`, also update
`config/trino/etc/catalog/iceberg.properties`, because Trino reads static catalog
properties from that file.

`polaris-setup` writes a marker to the `polaris-setup-state` Docker volume after
creating the catalog and grants. This makes repeated `docker compose up -d`
runs idempotent. Use `docker compose down -v` only when you want to recreate the
local Polaris catalog from scratch.

## 3. Verify Iceberg Read and Write

Run the sample SQL:

```bash
docker compose exec -T trino trino < init/trino/create-demo.sql
```

The script creates:

```text
iceberg.video.training_videos
```

Query the table:

```bash
docker compose exec trino trino \
  --execute "SELECT video_id, task, label_status, duration_seconds FROM iceberg.video.training_videos ORDER BY video_id"
```

Check Iceberg snapshots:

```bash
docker compose exec trino trino \
  --execute "SELECT committed_at, snapshot_id, operation FROM iceberg.video.\"training_videos\$snapshots\" ORDER BY committed_at DESC"
```

Check catalog persistence by restarting Polaris:

```bash
docker compose restart polaris
sleep 30
docker compose exec trino trino \
  --execute "SHOW TABLES FROM iceberg.video"
```

The `training_videos` table should still exist after the restart. If it
disappears, Polaris is not using PostgreSQL persistence.

## 4. Optional Superset BI

Start Superset with the `bi` profile:

```bash
docker compose --profile bi up -d --build superset
```

Open:

```text
http://localhost:8088
```

Default login:

```text
admin / admin
```

Create a database connection in Superset:

```text
trino://trino@trino:8080/iceberg
```

Use SQL Lab to query:

```sql
SELECT *
FROM video.training_videos;
```

Superset runs inside the Compose network, so the connection string uses the
Docker service name `trino` and container port `8080`, not the host port `8081`.

## 5. Optional DataHub Metadata Ingestion

DataHub is intentionally not part of the default Compose stack because its
quickstart requires more memory than the core lakehouse services. Start DataHub
separately:

```bash
datahub docker quickstart
```

Install ingestion plugins in a local virtual environment:

```bash
cd local/lakehouse
python3 -m venv .venv
. .venv/bin/activate
pip install --upgrade pip
pip install 'acryl-datahub[trino,superset]'
```

Ingest Trino/Iceberg metadata:

```bash
datahub ingest -c datahub/trino-recipe.yml
```

If Superset is running, ingest Superset metadata:

```bash
datahub ingest -c datahub/superset-recipe.yml
```

Open DataHub:

```text
http://localhost:9002
```

The provided recipes assume the ingestion CLI runs on the host machine. If you
run ingestion inside a Docker container, replace `localhost` with
`host.docker.internal` in the recipe files.

## 6. Cleanup

Stop services but keep volumes:

```bash
docker compose down
```

Remove local data volumes:

```bash
docker compose down -v
```

If DataHub quickstart was started separately, stop it with:

```bash
datahub docker nuke
```

## 7. Production Hardening

This PoC is not production-ready. For a production lakehouse:

- Run Polaris with a managed PostgreSQL metastore, backups, TLS, authentication
  hardening, and HA deployment topology.
- Use AWS S3 or a production S3-compatible object store with versioning,
  lifecycle policies, encryption, and backup controls.
- Move static credentials to Secrets Manager or External Secrets.
- Use IAM/IRSA instead of long-lived access keys when running on EKS.
- Run Trino with separate coordinator and worker nodes, resource groups, TLS,
  authentication, and query monitoring.
- Run Superset with an external metadata database, SSO, RBAC, and row-level
  security.
- Run DataHub as a managed or HA deployment with persistent Elasticsearch/OpenSearch,
  Kafka, and SQL metadata storage.
- Add ingestion orchestration with Airflow, Argo Workflows, Spark, Flink, or
  another pipeline engine for video metadata and feature generation.
- Add data quality checks, lineage validation, and retention policies for
  training datasets.
