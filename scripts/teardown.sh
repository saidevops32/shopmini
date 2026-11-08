#!/bin/bash
# Deletes ALL Azure resources of the project. The GitHub repo is NOT touched.
set -u
RG="${RG:-rg-shopmini-dev}"
echo "This DELETES resource group '$RG' and the Entra app 'shopmini-gha'."
read -r -p "Type the resource group name to confirm: " ans
[ "$ans" = "$RG" ] || { echo "aborted"; exit 1; }
az group delete -n "$RG" --yes --no-wait
for id in $(az ad app list --display-name shopmini-gha --query "[].id" -o tsv); do
  az ad app delete --id "$id" && echo "deleted Entra app $id"
done
echo "deletion runs in the background; check: az group list -o table"
