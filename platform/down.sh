#!/usr/bin/env bash
# Delete the cluster and the registry. Your git repo is not touched.
source "$(dirname "${BASH_SOURCE[0]}")/lib.sh"
cluster_exists && { say "Deleting cluster '$CLUSTER_NAME'"; kind delete cluster --name "$CLUSTER_NAME"; }
docker rm -f "$REG_NAME" >/dev/null 2>&1 && say "Removed the registry (images are gone too)"
say "Done"
