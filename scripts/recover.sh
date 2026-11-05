#!/bin/bash
# After a Cloud Shell reset: clone the repo, then run this from inside it.
# env.sh is git-ignored, so recreate it from the README ("Recovery after disconnect").
cd ~/shopmini || exit 1
export PATH="$HOME/bin:$PATH"
source env.sh
gh auth status 2>&1 | head -2
gitleaks version || echo "reinstall gitleaks (README)"
az aks show -g "$RG" -n "$AKS" --query powerState.code -o tsv
