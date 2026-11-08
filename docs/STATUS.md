# ShopMini status

Repo: github.com/saidevops32/shopmini (public). Azure free account, region southindia.
Never commit env.sh, passwords, or rendered manifests.

| Phase | What | Status |
|---|---|---|
| 0 | Repo, gitleaks guard, push protection, Dependabot | Done |
| 1 | RG, Key Vault, PostgreSQL + MySQL B1ms, ACR, AKS (1 x Standard_D2s_v4) | Done, then deleted to save cost |
| 2 | GitHub OIDC to Azure (no stored credentials) | Done |
| 3 | Key Vault via workload identity (allow and deny proven) | Done |
| 4a-d | auth, catalogue, checkout (outbox), notification-worker | Written, tested, images built, Trivy clean |
| 5a | Kubernetes manifests, per-service identities | Written, NOT applied yet |
| 5b | Deploy to AKS, prove the shop flow | Not started |
| 6-12 | Ingress, NetworkPolicies, clients, CI, ArgoCD, rollouts, observability | Starter files only (mobile, web, argocd, infra) |

## Rebuild Azure
1. Recreate env.sh from env.sh.example. Use a NEW Key Vault name (purge protection keeps the old one reserved).
   Keep LOCATION=southindia (PostgreSQL B1ms was SkuNotAvailable in centralindia).
2. `./scripts/provision-azure.sh <step>`, one step at a time (untested as a whole), see infra/README.md.
3. `az aks stop` when idle. `./scripts/teardown.sh` deletes everything.

## First suspects when Phase 5b pods fail
- RabbitMQ "read-only file system": set readOnlyRootFilesystem false for RabbitMQ only.
- Key Vault FailedMount: automountServiceAccountToken false with workload identity is untested.
- auth-service certificate error to PostgreSQL: temporary PG_SSL_VERIFY=false, then fix the CA chain.
- Pending pods: one 8 GB node is tight (ArgoCD would need a second node).
- Maven/Trivy HTTP 429: wait 30 minutes; do not loop.

## Known gaps
- Remove `apk upgrade libexpat` from catalogue/checkout Dockerfiles once the base image is clean.
- Dependabot PR #1 (Azure/login 3.1.0) is open; the prod OIDC credential is unproven.
- No dead-letter queue, idempotency key, stock reservation, login rate limiting, or catalogue write API.
- DB TLS is encrypted but the certificate is not verified. RabbitMQ data is on emptyDir. No PDB/HPA.
