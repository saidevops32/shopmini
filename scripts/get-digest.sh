#!/bin/bash
# Usage: ./scripts/get-digest.sh node 22-alpine   -> prints sha256:...
# Looks up the immutable digest of a Docker Hub official image tag.
set -euo pipefail
REPO="library/$1"; TAG="$2"
TOKEN=$(curl -fsS "https://auth.docker.io/token?service=registry.docker.io&scope=repository:${REPO}:pull" | jq -r .token)
curl -fsSI -H "Authorization: Bearer $TOKEN" \
  -H "Accept: application/vnd.oci.image.index.v1+json, application/vnd.docker.distribution.manifest.list.v2+json" \
  "https://registry-1.docker.io/v2/${REPO}/manifests/${TAG}" \
  | tr -d '\r' | awk -F': ' 'tolower($1)=="docker-content-digest"{print $2}'
