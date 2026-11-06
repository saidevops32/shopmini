# ShopMini - DevSecOps practice project

Mini Amazon-style shopping app (Flutter, React, Spring Boot, Node.js,
RabbitMQ, MySQL, PostgreSQL) on Azure AKS with GitHub Actions, OIDC,
Key Vault, ArgoCD and automated rollback.

> This is a PUBLIC repository. Never commit secrets, tokens, passwords,
> kubeconfig files or real database hostnames.

## Prerequisites
- Azure free account, Azure Cloud Shell (Bash)
- GitHub account

## Folder layout
mobile/ web/ services/ k8s/ infra/ argocd/ scripts/ docs/ .github/workflows/

## Phase 0: Setup and recovery

### First-time setup
1. `gh auth login -h github.com -p https -w -s workflow` then `gh auth setup-git`
2. Clone or create the repo in `~/shopmini`
3. `cp env.sh.example env.sh`, edit values (keep the same name suffix), `source env.sh`

### Recovery after Cloud Shell disconnect
    cd ~ && gh auth status || gh auth login -h github.com -p https -w -s workflow
    gh auth setup-git
    git clone https://github.com/<USER>/shopmini.git && cd shopmini
    cp env.sh.example env.sh && vim env.sh     # restore your values and suffix
    source env.sh
    az aks get-credentials -g $RG -n $AKS --overwrite-existing
    kubectl get nodes

### Saving work
    ./save.sh "phase N: description"     # secret-check, commit, push

### If a secret is ever pushed
Rotate the secret FIRST (deleting the commit does not make it safe), then clean history.

## Phase 1: Core Azure resources (southindia)
Why southindia: PostgreSQL Burstable B1ms returned `SkuNotAvailable` in
centralindia for this subscription, so databases and AKS live in southindia.
Key Vault stays in centralindia (purge protection prevents recreating it).

Order: resource group -> Key Vault -> DB passwords into Key Vault ->
PostgreSQL -> MySQL -> ACR -> AKS -> attach ACR -> firewall rules -> test.

CLI gotchas (these differ between PostgreSQL and MySQL):
| | PostgreSQL | MySQL |
|---|---|---|
| server flag | `-s` | `-n` |
| db create | `db create -s SERVER -n DB` | `db create -s SERVER -d DB` |
| firewall create | `-s SERVER -n RULE` | `-n SERVER -r RULE` |
- PostgreSQL: `--high-availability` is gone, use `--zonal-resiliency Disabled`.
- PostgreSQL created with `--public-access None` ends up with public access
  Disabled; run `az postgres flexible-server update --public-access Enabled`.
  With no firewall rules nobody can connect until one is added.
- `az aks create` rejects `--no-wait` together with `--attach-acr`: create the
  cluster with `--no-wait`, then `az aks update --attach-acr $ACR`.
- `NODE_RG` in env.sh must come AFTER `LOCATION` and `AKS`.

Firewall: only the AKS outbound IP may reach the databases:

    source env.sh && ./scripts/sync-db-firewall.sh

Node size: Standard_D2s_v4 x1 (B-series is not available on this subscription).
Cost control: `az aks stop -g $RG -n $AKS` after every session; after
`az aks start`, rerun the firewall sync script (the outbound IP can change).

OIDC subject format: this repo uses immutable subjects, so GitHub presents
`repo:OWNER@OWNERID/REPO@REPOID:...` (numeric IDs, safe against rename/transfer
attacks). Federated credentials must use that exact form (`AADSTS700213` = no match).
Check: `gh api repos/OWNER/REPO/actions/oidc/customization/sub`
Real subject from a failed job: `gh run view <id> --log-failed | grep subject`.
New credentials can take a few minutes to replicate in Entra ID; rerun before debugging.
The prod credential follows the same pattern (to be confirmed on the first prod deploy).

CI hygiene: Dependabot (.github/dependabot.yml) bumps pinned Action SHAs weekly.
Pipelines should pin `runs-on: ubuntu-24.04` rather than `ubuntu-latest`.

## Phase 3: Key Vault via workload identity
- User-assigned identity `id-shopmini-app`, role `Key Vault Secrets User` on the vault.
- Federated to ServiceAccount `shopmini/shopmini-sa` (subject
  `system:serviceaccount:shopmini:shopmini-sa`).
- `SecretProviderClass shopmini-kv` mounts `mysql-password` and `postgres-password`
  as files. Pods need label `azure.workload.identity/use: "true"` and
  `serviceAccountName: shopmini-sa`.
- Manifests hold placeholders only. Apply with `./scripts/apply-k8s.sh <files>`:
  it substitutes ONLY a fixed list of variables (plain `envsubst` blanks every `$x`,
  which broke our test pod's shell script).
- Proof: `kv-test` printed secret lengths (27) only; a pod using the `default`
  service account fails to mount (`kv-denied`).

## Recovery after Cloud Shell reset
1. `gh auth login -h github.com -p https -w -s workflow` then `gh auth setup-git`
2. `git clone https://github.com/<USER>/shopmini.git && cd shopmini`
3. Recreate `env.sh` from `env.sh.example` (replace SUFFIX and YOUR_GITHUB_USER,
   then add GHA_APP_ID, APP_MI_CLIENT_ID, TENANT_ID). Put derived values last.
4. Reinstall gitleaks into `~/bin`.
5. `source env.sh`, `az aks get-credentials -g $RG -n $AKS --overwrite-existing`.
6. `source scripts/load-db-secrets.sh` when DB passwords are needed.
Never name a variable GH_REPO (the gh CLI reads it); we use REPO_NAME.

## Phase 4a: auth-service (Node, PostgreSQL authdb)
- Endpoints: `POST /api/auth/register`, `POST /api/auth/login`, `GET /api/auth/me`.
- Probes: `/health/live` (process only, never the DB) and `/health/ready` (schema + DB).
- Secrets read from `/mnt/secrets/{postgres-password,jwt-secret}` (Key Vault CSI);
  env vars only as a local fallback. `jwt-secret` lives in Key Vault.
- Graceful shutdown on SIGTERM. Known gaps: no login rate limiting, no migrations.
- Dockerfile: two stages, base image pinned by digest (`./scripts/get-digest.sh node 22-alpine`),
  non-root uid 1000, `npm ci --omit=dev`, `.dockerignore`.
- Build: `az acr build -r $ACR -t auth-service:0.1.1 services/auth-service`.

Boot 4 changes we made: starter `spring-boot-starter-web` -> `spring-boot-starter-webmvc`,
test starter -> `spring-boot-starter-webmvc-test`, `@WebMvcTest` now in
`org.springframework.boot.webmvc.test.autoconfigure`. Found by Trivy before the first
deploy: 13 HIGH/CRITICAL findings on Boot 3.5; fixed by upgrading, not by pinning libraries.
Local tests in Cloud Shell: `mvn -B clean test -Djava.version=17` (the image builds with Java 21).

Image-scan lesson: `trivy fs` on the lockfile was clean, but `trivy image` found 10 HIGH
findings in npm's own bundled packages inside the node base image. The runtime stage now
deletes npm/npx/corepack/yarn (the service only runs `node`). Scan images, not just lockfiles.

Catalogue image: jar scan clean after the Boot 4.1 upgrade; 3 HIGH `libexpat` findings came
from the Alpine layer of the base image. Fix = newer base digest (Dependabot opens a PR when
one exists), or the temporary `apk upgrade --no-cache libexpat` line in the Dockerfile.
TODO: remove that line once `trivy image` is clean without it.
Maven Central rate-limits an IP with 429 after many back-to-back mvn/trivy runs (30 min block).
Don't loop them; cache `~/.m2` in CI.

## Phase 4c: checkout-service (Spring Boot 4.1, PostgreSQL orderdb, RabbitMQ)
- `POST /api/checkout/orders` (JWT from auth-service; prices come from catalogue-service,
  never from the client) and `GET /api/checkout/orders/{id}` (owner only; others get 404).
- Transactional outbox: the order and an `outbox` row commit together; `OutboxPublisher`
  sends rows to exchange `shop.events` (key `order.created`) and waits for the broker's
  confirm before marking them sent. RabbitMQ down = orders still work, messages wait.
- Delivery is at-least-once, so consumers must tolerate duplicates.
- Readiness checks the database only; liveness never checks anything external.
- Secrets from `/mnt/secrets`: `postgres-password`, `jwt-secret`, `rabbitmq-password`.
- Pinned versions: `nimbus-jose-jwt` 10.10 (not managed by Boot 4.1) and
  `rabbit-amqp-client.version` 5.37.0 (Boot's default 5.30.0 had 4 HIGH CVEs; fixed from 5.34.0).
  Remove the amqp override once Boot's own version is clean. Dependabot proposes bumps.
- Entity is `ShopOrder` (table `orders`) because ORDER is reserved in JPQL.
- Known gaps: no stock reservation, no idempotency key, `sslmode=require` (no cert check).
- Local tests: `mvn -B clean test -Djava.version=17`. Image: `checkout-service:0.1.0`.
- Lesson: commit work in progress before long builds; Cloud Shell can reset at any time.

## Phase 4d: notification-worker (Node, RabbitMQ consumer)
- Consumes `order.created` from queue `notification.order-created` (exchange `shop.events`,
  topic, durable). Declares the same exchange and queue as checkout-service, so start order
  does not matter. "Sends" a confirmation by logging one JSON line.
- Delivery is at-least-once: recent order ids are remembered in memory and repeats skipped
  (the memory resets on restart; a real email sender would need a database).
- Malformed messages are logged and dropped. Gap: no dead-letter queue (needs matching
  queue arguments on the checkout side too).
- Health on :3001: `/health/live` (process only), `/health/ready` (connected and consuming).
- Reconnects with backoff; graceful shutdown on SIGTERM.
- Secret from `/mnt/secrets/rabbitmq-password` (Key Vault). `amqplib` pinned to 2.2.1
  (2.0 only changed `heartbeat: 0`; Node 18+ required).
- Image `notification-worker:0.1.0`; Dockerfile mirrors auth-service (digest pin, npm removed).
