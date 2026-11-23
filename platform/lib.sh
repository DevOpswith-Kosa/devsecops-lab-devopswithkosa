#!/usr/bin/env bash
# Shared helpers for the platform scripts. Sourced, not run.
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
STATE="$ROOT/.local"                 # generated files, never committed
# shellcheck source=/dev/null
source "$ROOT/tools.env"
REG_NAME=kind-registry
REG_PORT=5001
AUDIENCE="kind-${CLUSTER_NAME}"
export KUBECONFIG="${KUBECONFIG:-$HOME/.kube/config}"
CTX="kind-${CLUSTER_NAME}"

c_ok=$'\e[32m'; c_warn=$'\e[33m'; c_err=$'\e[31m'; c_dim=$'\e[2m'; c_off=$'\e[0m'
say()  { printf '%s▸%s %s\n' "$c_ok" "$c_off" "$*"; }
warn() { printf '%s!%s %s\n' "$c_warn" "$c_off" "$*" >&2; }
die()  { printf '%s✘%s %s\n' "$c_err" "$c_off" "$*" >&2; exit 1; }
need() { command -v "$1" >/dev/null 2>&1 || die "'$1' is not installed. Run 'make doctor', or see STUDY_GUIDE.md section 3"; }
kc()   { kubectl --context "$CTX" "$@"; }

cluster_exists() { kind get clusters 2>/dev/null | grep -qx "$CLUSTER_NAME"; }

# The GitHub repository (owner/name, lowercase) the cluster trusts.
saved_repo() { cat "$STATE/github-repo" 2>/dev/null || true; }

render_auth_config() {   # $1 = owner/repo or empty
  local repo="${1:-unset/unset}"
  mkdir -p "$STATE/auth"
  sed -e "s|__REPO__|${repo}|g" -e "s|__AUDIENCE__|${AUDIENCE}|g" \
    "$ROOT/platform/auth/auth-config.yaml.tpl" > "$STATE/auth/auth-config.yaml.tmp"
  # Replace atomically: the API server watches this file and reloads it.
  mv "$STATE/auth/auth-config.yaml.tmp" "$STATE/auth/auth-config.yaml"
  # The audit policy lives alongside it (mounted read-only into the node).
  cp "$ROOT/platform/audit/audit-policy.yaml" "$STATE/auth/audit-policy.yaml"
}
