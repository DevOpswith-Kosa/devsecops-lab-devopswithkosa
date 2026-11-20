#!/usr/bin/env bash
# Render the manifests for one environment with an exact image digest.
#   ci/render.sh <dev|prod> <sha256:...> <version>   > manifests.yaml
# Deploying by digest (not by tag) means the cluster runs exactly the bytes
# that were scanned and signed. A tag can be moved; a digest cannot.
set -euo pipefail
env="$1" digest="$2" version="$3"
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
[[ "$env" =~ ^(dev|prod)$ ]] || { echo "env must be dev or prod" >&2; exit 2; }
[[ "$digest" =~ ^sha256:[0-9a-f]{64}$ ]] || { echo "not a digest: $digest" >&2; exit 2; }
# kustomize only accepts relative paths, so the wrapper lives inside k8s/.
tmp="$(mktemp -d "$ROOT/k8s/.render.XXXXXX")"; trap 'rm -rf "$tmp"' EXIT
cat > "$tmp/kustomization.yaml" <<YAML
apiVersion: kustomize.config.k8s.io/v1beta1
kind: Kustomization
namespace: $env
resources:
  - ../overlays/$env
images:
  - name: localhost:5001/kubenotes
    digest: $digest
configMapGenerator:
  - name: kubenotes
    behavior: merge
    literals:
      - APP_VERSION=$version
YAML
kubectl kustomize "$tmp"
