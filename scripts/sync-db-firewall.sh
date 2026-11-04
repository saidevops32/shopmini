#!/bin/bash
# Usage: source env.sh && ./scripts/sync-db-firewall.sh
# Allows ONLY the AKS outbound IP to reach both databases.
set -euo pipefail
IPID=$(az aks show -g "$RG" -n "$AKS" \
  --query "networkProfile.loadBalancerProfile.effectiveOutboundIPs[0].id" -o tsv)
IP=$(az network public-ip show --ids "$IPID" --query ipAddress -o tsv)
echo "AKS outbound IP: $IP"

# PostgreSQL: server=-s, rule=-n
az postgres flexible-server firewall-rule create -g "$RG" -s "$PG_SERVER" \
  -n allow-aks-egress --start-ip-address "$IP" --end-ip-address "$IP" -o none
# MySQL: server=-n, rule=-r
az mysql flexible-server firewall-rule create -g "$RG" -n "$MYSQL_SERVER" \
  -r allow-aks-egress --start-ip-address "$IP" --end-ip-address "$IP" -o none
echo "firewall rules set for $IP"
