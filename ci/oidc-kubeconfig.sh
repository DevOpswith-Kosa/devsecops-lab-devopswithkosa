#!/usr/bin/env bash
# Build a short-lived kubeconfig from a GitHub Actions OIDC token -- no stored
# admin credential anywhere. Run inside a job that has `id-token: write` and
# is bound to the `dev` or `prod` environment.
#
# Needs these repo VARIABLES (printed by `make oidc`):
#   KIND_API_SERVER  e.g. https://127.0.0.1:6443
#   KIND_AUDIENCE    e.g. kind-devsecops
#   KIND_CA_DATA     base64 of the cluster CA
# and these env vars GitHub sets automatically:
#   ACTIONS_ID_TOKEN_REQUEST_URL, ACTIONS_ID_TOKEN_REQUEST_TOKEN
#
#   eval "$(ci/oidc-kubeconfig.sh)"      # exports KUBECONFIG
set -euo pipefail
: "${KIND_API_SERVER:?set the KIND_API_SERVER repo variable}"
: "${KIND_AUDIENCE:?set the KIND_AUDIENCE repo variable}"
: "${KIND_CA_DATA:?set the KIND_CA_DATA repo variable}"
: "${ACTIONS_ID_TOKEN_REQUEST_URL:?run this inside a job with id-token: write}"

# 1. Ask GitHub for an OIDC token minted for this cluster's audience.
jwt="$(curl -fsSL -H "Authorization: Bearer $ACTIONS_ID_TOKEN_REQUEST_TOKEN" \
  "${ACTIONS_ID_TOKEN_REQUEST_URL}&audience=${KIND_AUDIENCE}" | sed -n 's/.*"value":"\([^"]*\)".*/\1/p')"
[[ -n "$jwt" ]] || { echo "could not obtain an OIDC token" >&2; exit 1; }

# 2. Write a kubeconfig that presents it as a bearer token.
kc="$(mktemp)"
printf '%s' "$KIND_CA_DATA" | base64 -d > "${kc}.ca"
kubectl config --kubeconfig="$kc" set-cluster kind \
  --server="$KIND_API_SERVER" --certificate-authority="${kc}.ca" --embed-certs=true >/dev/null
kubectl config --kubeconfig="$kc" set-credentials gha --token="$jwt" >/dev/null
kubectl config --kubeconfig="$kc" set-context kind --cluster=kind --user=gha >/dev/null
kubectl config --kubeconfig="$kc" use-context kind >/dev/null
echo "export KUBECONFIG=$kc"
