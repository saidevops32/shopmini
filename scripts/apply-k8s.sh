#!/bin/bash
# Usage: source env.sh && ./scripts/apply-k8s.sh k8s/base/FILE.yaml [more files]
# Replaces ONLY the listed variables; any other $ in the YAML is left alone.
set -euo pipefail
VARS='${APP_MI_CLIENT_ID} ${KV} ${TENANT_ID} ${ACR} ${PG_HOST} ${MYSQL_HOST}'
for f in "$@"; do
  envsubst "$VARS" < "$f" | kubectl apply -f -
done
