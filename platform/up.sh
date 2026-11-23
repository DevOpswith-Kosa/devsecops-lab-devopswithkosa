#!/usr/bin/env bash
# Create the local platform: a registry and a kind cluster that pulls from it.
# Safe to re-run: existing pieces are kept.
source "$(dirname "${BASH_SOURCE[0]}")/lib.sh"
"$ROOT/platform/doctor.sh" || exit 1

# 1. Local container registry (the "artifact store" of this lab).
if [[ "$(docker inspect -f '{{.State.Running}}' "$REG_NAME" 2>/dev/null)" != true ]]; then
  say "Starting the local registry on localhost:${REG_PORT}"
  docker rm -f "$REG_NAME" >/dev/null 2>&1 || true
  docker run -d --restart=always --name "$REG_NAME" \
    -p "127.0.0.1:${REG_PORT}:5000" registry:3 >/dev/null
else
  say "Registry already running on localhost:${REG_PORT}"
fi

# 2. The cluster.
if cluster_exists; then
  say "Cluster '$CLUSTER_NAME' already exists"
else
  render_auth_config "$(saved_repo)"
  mkdir -p "$STATE/audit"
  sed -e "s|__AUTH_DIR__|$STATE/auth|" -e "s|__AUDIT_DIR__|$STATE/audit|" \
      -e "s|__NODE_IMAGE__|$KIND_NODE_IMAGE|" -e "s|__CLUSTER_NAME__|$CLUSTER_NAME|" \
      "$ROOT/platform/kind-config.yaml.tpl" > "$STATE/kind-config.yaml"
  say "Creating kind cluster '$CLUSTER_NAME' (1–3 minutes)"
  kind create cluster --config "$STATE/kind-config.yaml" --wait 120s
fi

# 3. Teach containerd that localhost:5001 means the registry container.
for node in $(kind get nodes --name "$CLUSTER_NAME"); do
  docker exec "$node" mkdir -p "/etc/containerd/certs.d/localhost:${REG_PORT}"
  printf '[host."http://%s:5000"]\n' "$REG_NAME" |
    docker exec -i "$node" cp /dev/stdin "/etc/containerd/certs.d/localhost:${REG_PORT}/hosts.toml"
done
docker network connect kind "$REG_NAME" 2>/dev/null || true
kc apply -f - >/dev/null <<YAML
apiVersion: v1
kind: ConfigMap
metadata:
  name: local-registry-hosting
  namespace: kube-public
data:
  localRegistryHosting.v1: |
    host: "localhost:${REG_PORT}"
YAML

# 4. One namespace per environment.
#    NOTE: these start with NO Pod Security enforcement on purpose. That is
#    the insecure Part 1 baseline -- a container may run as root and nothing
#    stops it, which the attack lab (Part 2) relies on. Part 3, lab 15 turns
#    on the "restricted" standard (platform/psa-restricted.sh).
for ns in dev prod; do
  kc create namespace "$ns" --dry-run=client -o yaml | kc apply -f - >/dev/null
  kc label namespace "$ns" --overwrite devsecops.kubeacademy/environment="$ns" >/dev/null
done

say "Platform is up"
echo "  registry   localhost:${REG_PORT}"
echo "  cluster    $CTX  (kubectl --context $CTX get nodes)"
echo "  dev app    http://localhost:8080   (after the first deploy)"
echo "  prod app   http://localhost:8081   (after the first deploy)"
if [[ -n "$(saved_repo)" ]]; then
  echo "  trusts     GitHub Actions in $(saved_repo)"
else
  echo "  ${c_dim}GitHub OIDC trust not configured yet (Part 2, lab 12: make oidc REPO=owner/name)${c_off}"
fi
