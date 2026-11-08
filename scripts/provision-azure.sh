#!/bin/bash
# Rebuilds the Azure side one step at a time. Every step worked on its own during the first build;
# the script as a whole is UNTESTED, so run ONE step at a time and read the output.
# Usage: source env.sh && ./scripts/provision-azure.sh <step>
# Order: providers, rg, keyvault, databases, acr, images, rabbitmq-image, aks (wait), aks-finish, identities, oidc
set -eu
step="${1:-help}"
rand() { openssl rand -base64 48 | tr -dc 'A-Za-z0-9' | head -c "$1"; }
kvget() { az keyvault secret show --vault-name "$KV" -n "$1" --query value -o tsv; }
kvset_once() { az keyvault secret show --vault-name "$KV" -n "$1" -o none 2>/dev/null || az keyvault secret set --vault-name "$KV" -n "$1" --value "$2" -o none; }

case "$step" in
  providers)
    for p in Microsoft.DBforMySQL Microsoft.DBforPostgreSQL Microsoft.ContainerService Microsoft.ContainerRegistry \
             Microsoft.KeyVault Microsoft.OperationalInsights Microsoft.ManagedIdentity Microsoft.Network Microsoft.Compute; do
      az provider register --namespace "$p" -o none
    done
    echo "check each: az provider show -n Microsoft.DBforPostgreSQL --query registrationState -o tsv" ;;
  rg)
    az group create -n "$RG" -l "$LOCATION" --tags project=shopmini env=dev -o none ;;
  keyvault)
    az keyvault create -n "$KV" -g "$RG" -l "$LOCATION" --enable-rbac-authorization true \
      --enable-purge-protection true --retention-days 7 -o none
    az role assignment create --assignee-object-id "$(az ad signed-in-user show --query id -o tsv)" \
      --assignee-principal-type User --role "Key Vault Secrets Officer" \
      --scope "$(az keyvault show -n "$KV" --query id -o tsv)" -o none
    echo "waiting 60s for the role to apply"; sleep 60
    kvset_once mysql-password "$(rand 24)Aa1"
    kvset_once postgres-password "$(rand 24)Aa1"
    kvset_once jwt-secret "$(rand 40)"
    kvset_once rabbitmq-password "$(rand 32)"
    az keyvault secret list --vault-name "$KV" --query "[].name" -o tsv ;;
  databases)
    # centralindia returned SkuNotAvailable for PostgreSQL B1ms on this subscription; southindia worked
    PGP=$(kvget postgres-password); MYP=$(kvget mysql-password)
    az postgres flexible-server create -g "$RG" -n "$PG_SERVER" -l "$LOCATION" --admin-user "$PG_USER" \
      --admin-password "$PGP" --tier Burstable --sku-name Standard_B1ms --storage-size 32 --version 16 \
      --zonal-resiliency Disabled --public-access None --yes -o none
    # PostgreSQL ends up with public access DISABLED after 'None'; enable it (still no firewall rule)
    az postgres flexible-server update -g "$RG" -n "$PG_SERVER" --public-access Enabled -o none
    az postgres flexible-server db create -g "$RG" -s "$PG_SERVER" -n authdb -o none
    az postgres flexible-server db create -g "$RG" -s "$PG_SERVER" -n orderdb -o none
    az mysql flexible-server create -g "$RG" -n "$MYSQL_SERVER" -l "$LOCATION" --admin-user "$MYSQL_USER" \
      --admin-password "$MYP" --tier Burstable --sku-name Standard_B1ms --storage-size 32 --version 8.0.21 \
      --public-access None --yes -o none
    az mysql flexible-server db create -g "$RG" -s "$MYSQL_SERVER" -d cataloguedb -o none ;;
  acr)
    az acr create -g "$RG" -n "$ACR" --sku Basic --admin-enabled false -l "$LOCATION" -o none ;;
  images)
    az acr build -r "$ACR" -t auth-service:0.1.1 services/auth-service
    az acr build -r "$ACR" -t catalogue-service:0.1.2 services/catalogue-service
    az acr build -r "$ACR" -t checkout-service:0.1.0 services/checkout-service
    az acr build -r "$ACR" -t notification-worker:0.1.0 services/notification-worker ;;
  rabbitmq-image)
    D=$(./scripts/get-digest.sh rabbitmq 4-alpine)
    case "$D" in sha256:*) ;; *) echo "no digest, stop"; exit 1 ;; esac
    az acr import -n "$ACR" --source "docker.io/library/rabbitmq@$D" --image rabbitmq:4-alpine --force ;;
  aks)
    # B-series VMs were unavailable on this subscription; check sizes/quota first (az vm list-skus, az vm list-usage)
    az aks create -g "$RG" -n "$AKS" -l "$LOCATION" --tier free --nodepool-name sys \
      --node-count "$NODE_COUNT" --node-vm-size "$NODE_SIZE" --node-osdisk-size 64 --node-osdisk-type Managed \
      --network-plugin azure --network-policy azure --enable-oidc-issuer --enable-workload-identity \
      --enable-addons azure-keyvault-secrets-provider --generate-ssh-keys --tags project=shopmini env=dev --no-wait
    echo "poll: az aks show -g $RG -n $AKS --query provisioningState -o tsv   (wait for Succeeded)" ;;
  aks-finish)
    az aks update -g "$RG" -n "$AKS" --attach-acr "$ACR" -o none   # cannot be combined with --no-wait at create
    az aks get-credentials -g "$RG" -n "$AKS" --overwrite-existing
    kubectl get nodes
    ./scripts/sync-db-firewall.sh ;;
  identities)
    ./scripts/setup-identities.sh ;;
  oidc)
    : "${GH_USER:?}" "${REPO_NAME:?}"
    TENANT=$(az account show --query tenantId -o tsv); SUB=$(az account show --query id -o tsv)
    APP_ID=$(az ad app list --display-name shopmini-gha --query "[0].appId" -o tsv)
    [ -n "$APP_ID" ] || APP_ID=$(az ad app create --display-name shopmini-gha --query appId -o tsv)
    az ad sp show --id "$APP_ID" -o none 2>/dev/null || az ad sp create --id "$APP_ID" -o none
    SP_OID=$(az ad sp show --id "$APP_ID" --query id -o tsv)
    ACR_ID=$(az acr show -n "$ACR" --query id -o tsv)
    for role in AcrPush Reader; do
      have=$(az role assignment list --assignee "$SP_OID" --scope "$ACR_ID" --role "$role" --query "[0].id" -o tsv)
      [ -n "$have" ] || az role assignment create --assignee-object-id "$SP_OID" \
        --assignee-principal-type ServicePrincipal --role "$role" --scope "$ACR_ID" -o none
    done
    BASE=$(gh api "repos/$GH_USER/$REPO_NAME/actions/oidc/customization/sub" --jq '.sub_claim_prefix // empty')
    [ -n "$BASE" ] || BASE="repo:$GH_USER/$REPO_NAME"
    for pair in "gh-main-id|ref:refs/heads/main" "gh-env-dev-id|environment:dev" "gh-env-prod-id|environment:prod"; do
      n=${pair%%|*}; s=${pair##*|}
      az ad app federated-credential list --id "$APP_ID" --query "[?name=='$n'].name" -o tsv | grep -q . && continue
      printf '{"name":"%s","issuer":"https://token.actions.githubusercontent.com","subject":"%s","audiences":["api://AzureADTokenExchange"]}' "$n" "$BASE:$s" > /tmp/fc.json
      az ad app federated-credential create --id "$APP_ID" --parameters @/tmp/fc.json -o none
      rm -f /tmp/fc.json
    done
    R="$GH_USER/$REPO_NAME"
    gh variable set AZURE_CLIENT_ID --body "$APP_ID" -R "$R"
    gh variable set AZURE_TENANT_ID --body "$TENANT" -R "$R"
    gh variable set AZURE_SUBSCRIPTION_ID --body "$SUB" -R "$R"
    gh variable set ACR_NAME --body "$ACR" -R "$R"
    gh variable set AZURE_RG --body "$RG" -R "$R"
    echo "add to env.sh: export GHA_APP_ID=$APP_ID" ;;
  *)
    sed -n '2,6p' "$0" ;;
esac
