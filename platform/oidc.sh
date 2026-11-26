#!/usr/bin/env bash
# Make the cluster trust GitHub Actions OIDC tokens from ONE repository,
# and give that repository's dev/prod environments a least-privilege Role.
#   platform/oidc.sh owner/repo
source "$(dirname "${BASH_SOURCE[0]}")/lib.sh"
repo="$(printf '%s' "${1:-}" | tr '[:upper:]' '[:lower:]')"
[[ "$repo" =~ ^[a-z0-9-]+/[a-z0-9._-]+$ ]] || die "usage: make oidc REPO=<owner>/<repo>   e.g. make oidc REPO=alice/practice-lab-alice"
cluster_exists || die "No cluster yet. Run: make up"

mkdir -p "$STATE"; echo "$repo" > "$STATE/github-repo"
render_auth_config "$repo"
say "API server now trusts tokens from https://token.actions.githubusercontent.com"
echo "    audience  $AUDIENCE"
echo "    repo      $repo   branch main   environments dev, prod"

for env in dev prod; do
  sed -e "s|__REPO__|$repo|g" -e "s|__ENV__|$env|g" "$ROOT/platform/rbac/ci-deployer.yaml.tpl" | kc apply -f - >/dev/null
  echo "    RBAC      github:repo:$repo:environment:$env  →  Role ci-deployer in namespace $env"
done

# The API server re-reads the file within about a minute. Show it worked.
say "Waiting for the API server to load the new config"
for _ in $(seq 1 30); do
  if docker exec "${CLUSTER_NAME}-control-plane" grep -q "$repo" /etc/kubernetes/auth/auth-config.yaml 2>/dev/null; then break; fi
  sleep 2
done

ca_file="$STATE/cluster-ca.crt"
kc config view --raw --minify -o jsonpath='{.clusters[0].cluster.certificate-authority-data}' | base64 -d > "$ca_file" 2>/dev/null \
  || kc config view --raw --minify -o jsonpath='{.clusters[0].cluster.certificate-authority-data}' | base64 -D > "$ca_file"
say "Done. Add these as GitHub repository VARIABLES (not secrets, they are public):"
echo "    KIND_API_SERVER = https://127.0.0.1:6443"
echo "    KIND_AUDIENCE   = $AUDIENCE"
echo "    KIND_CA_DATA    = (the line below)"
base64 < "$ca_file" | tr -d '\n'; echo
command -v gh >/dev/null && echo "  ${c_dim}or let gh do it: make oidc-vars${c_off}"
