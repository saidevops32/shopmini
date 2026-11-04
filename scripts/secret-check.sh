#!/bin/bash
# Scans STAGED changes for secrets. Exit 1 blocks the push.
cd "$(git rev-parse --show-toplevel)" || exit 1
if command -v gitleaks >/dev/null 2>&1; then
  if gitleaks protect --staged --redact; then
    echo "secret-check: clean (gitleaks)"; exit 0
  else
    echo "secret-check: BLOCKED - possible secret found"; exit 1
  fi
fi
# fallback if gitleaks is missing
if git diff --cached -U0 | grep -E '^\+' | grep -iE \
  'password[[:space:]]*[=:][[:space:]]*[^ ]{6,}|BEGIN .*PRIVATE KEY|AKIA[0-9A-Z]{16}|ghp_[A-Za-z0-9]{36}'; then
  echo "secret-check: BLOCKED - possible secret found"; exit 1
fi
echo "secret-check: clean (grep fallback)"
