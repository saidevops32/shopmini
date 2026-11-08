# Infrastructure

Current state: the Azure side is created with `az` commands, not infrastructure-as-code.
`scripts/provision-azure.sh <step>` holds them in order (untested as a whole; run one step at a time):
providers, rg, keyvault, databases, acr, images, rabbitmq-image, aks, aks-finish, identities, oidc.

Facts learned the hard way:
- PostgreSQL B1ms returned SkuNotAvailable in centralindia; southindia worked.
- B-series VMs were unavailable; Standard_D2s_v4 worked. Check quota first.
- Key Vault has purge protection: after deletion the name is reserved for 7 days, so use a new name.
- `az aks create` cannot combine --no-wait with --attach-acr: attach afterwards.
- PostgreSQL created with --public-access None ends up disabled; run `update --public-access Enabled`.

Phase 12 goal: convert this to Bicep or Terraform with remote state in a storage account
(never committed), and add budgets, tags and Azure Policy.
