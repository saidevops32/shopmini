#!/bin/bash
# Usage: source env.sh && ./scripts/render-k8s.sh [overlay] > /tmp/rendered.yaml
# Renders the kustomize overlay, then fills in ONLY the listed variables.
# NEVER commit the rendered output (it contains real hostnames and identity IDs).
set -euo pipefail
cd "$(dirname "$0")/.."
OVERLAY="${1:-dev}"
source scripts/load-identities.sh

for v in ACR KV TENANT_ID PG_HOST MYSQL_HOST PG_USER MYSQL_USER \
         AUTH_MI_CLIENT_ID CATALOGUE_MI_CLIENT_ID CHECKOUT_MI_CLIENT_ID WORKER_MI_CLIENT_ID RABBITMQ_MI_CLIENT_ID; do
  [ -n "${!v:-}" ] || { echo "variable $v is empty" >&2; exit 1; }
done

VARS='${ACR} ${KV} ${TENANT_ID} ${PG_HOST} ${MYSQL_HOST} ${PG_USER} ${MYSQL_USER} ${AUTH_MI_CLIENT_ID} ${CATALOGUE_MI_CLIENT_ID} ${CHECKOUT_MI_CLIENT_ID} ${WORKER_MI_CLIENT_ID} ${RABBITMQ_MI_CLIENT_ID}'
OUT=$(kubectl kustomize "k8s/overlays/$OVERLAY" | envsubst "$VARS")
if grep -qE '\$\{[A-Z_]+\}' <<<"$OUT"; then
  echo "unresolved placeholders:" >&2
  grep -nE '\$\{[A-Z_]+\}' <<<"$OUT" >&2
  exit 1
fi
printf '%s\n' "$OUT"
