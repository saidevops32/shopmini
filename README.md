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
- Build: `az acr build -r $ACR -t auth-service:0.1.0 services/auth-service`.
