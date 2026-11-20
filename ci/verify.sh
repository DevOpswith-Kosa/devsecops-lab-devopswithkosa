#!/usr/bin/env bash
# Verify an image was keyless-signed by a workflow in THIS repo on main.
#   ci/verify.sh <image@sha256:...> <owner/repo>
set -euo pipefail
ref="${1:?image@digest}"; repo="${2:?owner/repo}"
cosign verify "$ref" \
  --certificate-identity-regexp "^https://github.com/${repo}/\.github/workflows/.+@refs/heads/main$" \
  --certificate-oidc-issuer "https://token.actions.githubusercontent.com" \
  >/dev/null
echo "verified: $ref was signed by $repo on main"
