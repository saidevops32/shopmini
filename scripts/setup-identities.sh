#!/bin/bash
# Usage: source env.sh && ./scripts/setup-identities.sh
# One managed identity per service, allowed to read ONLY its own Key Vault secrets,
# and trusted only for its own Kubernetes service account.
set -euo pipefail
: "${RG:?}" "${KV:?}" "${AKS:?}" "${LOCATION:?}"

secrets_for() {
  case "$1" in
    auth)      echo "postgres-password jwt-secret" ;;
    catalogue) echo "mysql-password" ;;
    checkout)  echo "postgres-password jwt-secret rabbitmq-password" ;;
    worker)    echo "rabbitmq-password" ;;
    rabbitmq)  echo "rabbitmq-password" ;;
  esac
}

ISSUER=$(az aks show -g "$RG" -n "$AKS" --query oidcIssuerProfile.issuerUrl -o tsv)
KV_ID=$(az keyvault show -n "$KV" --query id -o tsv)
[ -n "$ISSUER" ] && [ -n "$KV_ID" ] || { echo "issuer or vault id is empty" >&2; exit 1; }

for svc in auth catalogue checkout worker rabbitmq; do
  id="id-shopmini-$svc"
  echo "== $id" >&2
  az identity create -g "$RG" -n "$id" -l "$LOCATION" -o none
  principal=$(az identity show -g "$RG" -n "$id" --query principalId -o tsv)
  for s in $(secrets_for "$svc"); do
    out=$(az role assignment create --assignee-object-id "$principal" \
          --assignee-principal-type ServicePrincipal \
          --role "Key Vault Secrets User" --scope "$KV_ID/secrets/$s" -o none 2>&1) || {
      echo "$out" | grep -qi "already exists" || { echo "$out" >&2; exit 1; }
    }
    echo "   may read: $s" >&2
  done
  az identity federated-credential create -g "$RG" --identity-name "$id" --name "fc-$svc" \
    --issuer "$ISSUER" --subject "system:serviceaccount:shopmini:$svc-sa" \
    --audiences api://AzureADTokenExchange -o none
  echo "   trusts: system:serviceaccount:shopmini:$svc-sa" >&2
done
echo "done" >&2
