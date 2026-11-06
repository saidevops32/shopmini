#!/bin/bash
# Usage: source scripts/load-identities.sh   (after: source env.sh)
# Looks the client IDs up from Azure each time, so nothing has to be stored in env.sh.
for svc in auth catalogue checkout worker rabbitmq; do
  var="$(echo "$svc" | tr a-z A-Z)_MI_CLIENT_ID"
  export "$var=$(az identity show -g "$RG" -n "id-shopmini-$svc" --query clientId -o tsv 2>/dev/null)"
done
