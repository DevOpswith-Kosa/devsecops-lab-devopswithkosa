#!/usr/bin/env bash
# Install OPA Gatekeeper and the admission policies in platform/gatekeeper/.
source "$(dirname "${BASH_SOURCE[0]}")/lib.sh"
cluster_exists || die "No cluster yet. Run: make up"
if ! kc get ns gatekeeper-system >/dev/null 2>&1; then
  say "Installing OPA Gatekeeper $GATEKEEPER_VERSION"
  kc apply -f "https://raw.githubusercontent.com/open-policy-agent/gatekeeper/${GATEKEEPER_VERSION}/deploy/gatekeeper.yaml" >/dev/null
fi
kc -n gatekeeper-system rollout status deploy/gatekeeper-controller-manager --timeout=180s
kc -n gatekeeper-system rollout status deploy/gatekeeper-audit --timeout=180s
say "Loading constraint templates (the Rego policies)"
kc apply -f "$ROOT/platform/gatekeeper/templates/"
for t in $(kc get constrainttemplates -o name); do
  kc wait --for=jsonpath='{.status.created}'=true "$t" --timeout=60s >/dev/null
done
# The CRDs for each constraint kind appear a moment after the template.
sleep 5
say "Loading constraints (where each policy applies)"
kc apply -f "$ROOT/platform/gatekeeper/constraints/"
say "Gatekeeper is enforcing in namespaces dev and prod:"
kc get constraints 2>/dev/null || true
