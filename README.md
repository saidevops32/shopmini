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
