#!/bin/bash
# Usage: source scripts/load-db-secrets.sh   (after: source env.sh)
export MYSQL_PASS=$(az keyvault secret show --vault-name "$KV" -n mysql-password    --query value -o tsv)
export PG_PASS=$(az keyvault secret show    --vault-name "$KV" -n postgres-password --query value -o tsv)
echo "loaded DB secrets into this shell only (not saved to disk)"
