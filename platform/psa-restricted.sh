#!/usr/bin/env bash
# Part 3, lab 15: turn on the Pod Security "restricted" standard in dev and
# prod. After this, a root / privileged / writable-rootfs pod is rejected by
# the API server at admission -- the insecure Part 1 deployment no longer
# fits, which is the point.
source "$(dirname "${BASH_SOURCE[0]}")/lib.sh"
cluster_exists || die "No cluster yet. Run: make up"
for ns in dev prod; do
  kc label namespace "$ns" --overwrite \
    pod-security.kubernetes.io/enforce=restricted \
    pod-security.kubernetes.io/enforce-version=latest \
    pod-security.kubernetes.io/warn=restricted \
    pod-security.kubernetes.io/audit=restricted >/dev/null
  say "namespace $ns now enforces the 'restricted' Pod Security standard"
done
echo "Try the insecure deployment again -- the API server should refuse it:"
echo "  kubectl --context $CTX -n dev apply -f k8s/insecure/"
