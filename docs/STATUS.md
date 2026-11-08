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
| 5a | Kubernetes manifests (kustomize), per-service identities | Written, NOT applied to a cluster yet |
| 5b | Deploy to AKS and prove the shop flow | Not started |
| 6-12 | Ingress, NetworkPolicies, clients, CI, ArgoCD, rollouts, observability | Not started |

## To rebuild Azure
1. Recreate env.sh from env.sh.example. Use a NEW Key Vault name (purge protection keeps the old one reserved).
   Keep LOCATION=southindia (PostgreSQL B1ms returned SkuNotAvailable in centralindia).
2. Order: resource group, Key Vault + 4 secrets (mysql-password, postgres-password, jwt-secret, rabbitmq-password),
   PostgreSQL + MySQL, ACR, `az acr build` for the 4 services, import rabbitmq:4-alpine,
   AKS (create with --no-wait, then `az aks update --attach-acr`), `./scripts/sync-db-firewall.sh`,
   `./scripts/setup-identities.sh`, then GitHub OIDC (see README Phase 2).
3. `az aks stop` when idle. `./scripts/teardown.sh` deletes everything.

## Phase 5b: deploy and prove it
source env.sh; az aks start; az aks get-credentials; ./scripts/sync-db-firewall.sh
./scripts/render-k8s.sh > /tmp/rendered.yaml && kubectl apply -f /tmp/rendered.yaml && rm /tmp/rendered.yaml
Expect 5 pods Ready; worker log says "consuming from notification.order-created".
Then port-forward the services, register, log in, list products, place an order, read the worker log.
Outbox proof: scale rabbitmq to 0, place an order (must still return 201), scale back to 1, confirmation arrives.

First suspects if a pod fails:
- RabbitMQ "read-only file system": set readOnlyRootFilesystem false for RabbitMQ only.
- Key Vault FailedMount: automountServiceAccountToken false with workload identity is untested; remove it from that pod.
- auth-service certificate error to PostgreSQL: temporary PG_SSL_VERIFY=false, then fix the CA chain.
- Pending pods: single 8 GB node is tight; lower Java requests.
- Maven/Trivy HTTP 429: wait 30 minutes; do not loop.

## Remaining phases
6 ingress path routing (check the community ingress-nginx is still maintained first), NetworkPolicies, admission rule.
7 Flutter + React clients. 8 CI (gitleaks, hadolint, tests, CodeQL, Trivy, SBOM, cosign, push via OIDC).
9 ArgoCD (placeholders need real values without committing hostnames). 10 Argo Rollouts canary + rollback.
11 observability. 12 Application Gateway (not free), cleanup.

## Known gaps
- Remove `apk upgrade libexpat` from catalogue/checkout Dockerfiles once the base image is clean.
- Dependabot PR #1 (Azure/login 3.1.0) is open; the prod OIDC credential is unproven.
- No dead-letter queue, idempotency key, stock reservation, login rate limiting; DB TLS not certificate-verified.
- RabbitMQ data is on emptyDir; no PDB/HPA (1 replica); amqplib 2.2.1 and RabbitMQ client 5.37.0 unproven at runtime.
