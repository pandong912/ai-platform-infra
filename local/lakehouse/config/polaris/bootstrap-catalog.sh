#!/bin/sh
set -eu

apk add --no-cache jq >/dev/null

REALM="${POLARIS_REALM:-POLARIS}"
ROOT_CLIENT_ID="${POLARIS_ROOT_CLIENT_ID:-root}"
ROOT_CLIENT_SECRET="${POLARIS_ROOT_CLIENT_SECRET:-s3cr3t}"
CATALOG_NAME="${POLARIS_CATALOG_NAME:-quickstart_catalog}"
WAREHOUSE_BUCKET="${MINIO_WAREHOUSE_BUCKET:-warehouse}"
MINIO_ENDPOINT_INTERNAL="${MINIO_ENDPOINT_INTERNAL:-http://minio:9000}"
MINIO_REGION="${MINIO_REGION:-us-east-1}"
STATE_FILE="${POLARIS_SETUP_STATE_FILE:-/state/polaris-setup-done}"

if [ -f "$STATE_FILE" ]; then
  echo "Polaris catalog bootstrap already completed; skipping."
  exit 0
fi

mkdir -p "$(dirname "$STATE_FILE")"

request() {
  method="$1"
  url="$2"
  data="${3:-}"
  expected="${4:-200 201 204 409}"

  if [ -n "$data" ]; then
    status="$(curl -s -S -o /tmp/polaris-response.json -w '%{http_code}' \
      -X "$method" "$url" \
      -H "Authorization: Bearer $TOKEN" \
      -H "Polaris-Realm: $REALM" \
      -H "Accept: application/json" \
      -H "Content-Type: application/json" \
      -d "$data")"
  else
    status="$(curl -s -S -o /tmp/polaris-response.json -w '%{http_code}' \
      -X "$method" "$url" \
      -H "Authorization: Bearer $TOKEN" \
      -H "Polaris-Realm: $REALM" \
      -H "Accept: application/json")"
  fi

  case " $expected " in
    *" $status "*) return 0 ;;
    *)
      echo "Unexpected Polaris response $status from $method $url" >&2
      cat /tmp/polaris-response.json >&2
      exit 1
      ;;
  esac
}

echo "Obtaining Polaris root access token..."
TOKEN_RESPONSE="$(curl --fail-with-body -s -S -X POST http://polaris:8181/api/catalog/v1/oauth/tokens \
  -H "Content-Type: application/x-www-form-urlencoded" \
  -d "grant_type=client_credentials&client_id=${ROOT_CLIENT_ID}&client_secret=${ROOT_CLIENT_SECRET}&scope=PRINCIPAL_ROLE:ALL")"
TOKEN="$(echo "$TOKEN_RESPONSE" | jq -r '.access_token')"

if [ -z "$TOKEN" ] || [ "$TOKEN" = "null" ]; then
  echo "Failed to parse Polaris access token" >&2
  echo "$TOKEN_RESPONSE" >&2
  exit 1
fi

echo "Creating Polaris catalog ${CATALOG_NAME}..."
request POST "http://polaris:8181/api/management/v1/catalogs" "{
  \"catalog\": {
    \"name\": \"${CATALOG_NAME}\",
    \"type\": \"INTERNAL\",
    \"readOnly\": false,
    \"properties\": {
      \"default-base-location\": \"s3://${WAREHOUSE_BUCKET}\"
    },
    \"storageConfigInfo\": {
      \"storageType\": \"S3\",
      \"allowedLocations\": [\"s3://${WAREHOUSE_BUCKET}\", \"s3://${WAREHOUSE_BUCKET}/*\"],
      \"endpoint\": \"${MINIO_ENDPOINT_INTERNAL}\",
      \"endpointInternal\": \"${MINIO_ENDPOINT_INTERNAL}\",
      \"pathStyleAccess\": true,
      \"region\": \"${MINIO_REGION}\"
    }
  }
}"

echo "Creating Polaris roles..."
request POST "http://polaris:8181/api/management/v1/principal-roles" \
  '{"principalRole": {"name": "trino_admin_role", "properties": {}}}'

request POST "http://polaris:8181/api/management/v1/catalogs/${CATALOG_NAME}/catalog-roles" \
  '{"catalogRole": {"name": "catalog_admin_role", "properties": {}}}'

echo "Assigning Polaris roles to root principal..."
request PUT "http://polaris:8181/api/management/v1/principals/${ROOT_CLIENT_ID}/principal-roles" \
  '{"principalRole": {"name": "trino_admin_role"}}' \
  "200 201 204 409 500"

request PUT "http://polaris:8181/api/management/v1/principal-roles/trino_admin_role/catalog-roles/${CATALOG_NAME}" \
  '{"catalogRole": {"name": "catalog_admin_role"}}' \
  "200 201 204 409 500"

echo "Granting catalog content privilege..."
request PUT "http://polaris:8181/api/management/v1/catalogs/${CATALOG_NAME}/catalog-roles/catalog_admin_role/grants" \
  '{"type": "catalog", "privilege": "CATALOG_MANAGE_CONTENT"}' \
  "200 201 204 409 500"

touch "$STATE_FILE"
echo "Polaris catalog bootstrap complete."
