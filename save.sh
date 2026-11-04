#!/bin/bash
# Usage: ./save.sh "phase N: what changed"
cd ~/shopmini || exit 1
git add -A
./scripts/secret-check.sh || { git reset -q; exit 1; }
git commit -m "${1:-update}" || echo "Nothing to commit"
git push -u origin main
