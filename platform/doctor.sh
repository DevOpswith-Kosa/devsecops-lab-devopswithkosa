#!/usr/bin/env bash
# Preflight: can this machine run the lab? Prints one line per check and the
# exact fix for anything that is wrong. Run it any time with `make doctor`;
# `make up` runs it first and stops if a hard requirement is missing.
source "$(dirname "${BASH_SOURCE[0]}")/lib.sh"
set +e
fail=0
ok()   { printf '  %s✔%s %s\n' "$c_ok" "$c_off" "$*"; }
bad()  { printf '  %s✘%s %s\n' "$c_err" "$c_off" "$*"; fail=1; }
meh()  { printf '  %s!%s %s\n' "$c_warn" "$c_off" "$*"; }
ver_ge() { [[ "$(printf '%s\n%s\n' "$2" "$1" | sort -V | head -1)" == "$2" ]]; }  # $1 >= $2
port_busy() { (exec 3<>"/dev/tcp/127.0.0.1/$1") 2>/dev/null; }
case "$(uname -m)" in aarch64|arm64) ARCH=arm64 ;; *) ARCH=amd64 ;; esac
OS="$(uname -s | tr '[:upper:]' '[:lower:]')"

echo "Checking this machine"

# 1. Where we are running.
case "$OS" in
  linux)
    if grep -qi microsoft /proc/version 2>/dev/null; then
      case "$ROOT" in
        /mnt/*) bad "the repo is on the Windows drive ($ROOT): slow and breaks file permissions.
      Clone it inside WSL instead, e.g. under ~ (STUDY_GUIDE.md, section 3b step 4)" ;;
        *) ok "WSL2, repo in the Linux filesystem" ;;
      esac
    else ok "Linux"; fi ;;
  darwin) ok "macOS" ;;
  *) bad "unsupported environment '$(uname -s)'. On Windows run the lab inside WSL2 (STUDY_GUIDE.md, section 3b)" ;;
esac

# 2. Scripts must have Unix line endings (a Windows git checkout can add CRLF).
if grep -q $'\r' "$ROOT/platform/up.sh" "$ROOT/Makefile" 2>/dev/null; then
  bad "files have Windows (CRLF) line endings. Re-clone inside WSL/Linux, or run:
      git config core.autocrlf false && git rm -rq --cached . && git reset -q --hard"
fi

# 3. Required tools.
for t in docker kind kubectl git make; do
  if command -v "$t" >/dev/null 2>&1; then ok "$t installed"
  else bad "$t is not installed (STUDY_GUIDE.md, section 3)"; fi
done
command -v gh >/dev/null 2>&1 && ok "gh installed" \
  || meh "gh not installed: needed for Lab 1 (your repo), the runner and OIDC labs"
command -v python3 >/dev/null 2>&1 && ok "python3 installed" \
  || meh "python3 not installed: needed for the Part 2 attacker box and Part 4 (detect, AI)"

# 4. kind must understand the pinned node image (older kind fails with
#    "your configuration file uses an old API spec: kubeadm.k8s.io/v1beta3").
if command -v kind >/dev/null 2>&1; then
  kv="$(kind version 2>/dev/null | grep -oE 'v[0-9]+\.[0-9]+\.[0-9]+' | head -1)"
  if [[ -n "$kv" ]] && ver_ge "${kv#v}" "${KIND_VERSION#v}"; then
    ok "kind $kv (needs >= $KIND_VERSION for $KIND_NODE_IMAGE)"
  else
    bad "kind ${kv:-unknown} is too old for $KIND_NODE_IMAGE; need >= $KIND_VERSION. Upgrade:
      curl -Lo kind https://kind.sigs.k8s.io/dl/$KIND_VERSION/kind-$OS-$ARCH && sudo install kind /usr/local/bin/ && rm kind"
  fi
fi

# 5. Docker engine running, and how much memory it has.
if docker info >/dev/null 2>&1; then
  ok "Docker engine running"
  mem="$(docker info --format '{{.MemTotal}}' 2>/dev/null)"
  if [[ "$mem" =~ ^[0-9]+$ ]]; then
    gb=$(( mem / 1024 / 1024 / 1024 ))
    if (( gb < 4 )); then bad "Docker has only ${gb} GB of RAM; the lab needs at least 4 (8 recommended)"
    elif (( gb < 7 )); then meh "Docker has ${gb} GB of RAM; 8 GB is recommended (WSL: set memory=8GB in .wslconfig)"
    else ok "Docker has ${gb} GB of RAM"; fi
  fi
  others="$(docker ps --format '{{.Names}}' | grep -E -- '-control-plane$|^minikube$' | grep -vx "${CLUSTER_NAME}-control-plane" | tr '\n' ' ')"
  [[ -n "$others" ]] && meh "other clusters are running and using RAM: ${others}
      stop them if things get slow: docker stop <name>  (data is kept; docker start brings them back)"
else
  bad "Docker is not running. Start Docker Desktop (on WSL also enable
      Settings > Resources > WSL Integration for this distro), or: sudo systemctl start docker"
fi

# 6. Ports the lab binds on 127.0.0.1 (only matters before the cluster exists).
if ! cluster_exists; then
  for p in 6443 8080 8081; do
    if port_busy "$p"; then
      hint=""; [[ $p == 6443 ]] && hint=" (Docker Desktop's built-in Kubernetes uses it: Settings > Kubernetes > disable)"
      bad "port $p is already in use$hint"
    fi
  done
fi
if [[ "$(docker inspect -f '{{.State.Running}}' "$REG_NAME" 2>/dev/null)" != true ]] && port_busy "$REG_PORT"; then
  bad "port $REG_PORT (local registry) is already in use by something else"
fi

if (( fail )); then
  die "Fix the ✘ items above, then run: make up"
fi
say "This machine is ready"
