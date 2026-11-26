#!/usr/bin/env bash
# One screen that tells you what is running.
source "$(dirname "${BASH_SOURCE[0]}")/lib.sh"
row() { printf '  %-22s %s\n' "$1" "$2"; }
echo "Platform"
if [[ "$(docker inspect -f '{{.State.Running}}' "$REG_NAME" 2>/dev/null)" == true ]]; then
  row registry "✔ localhost:${REG_PORT}  ($(curl -s "http://localhost:${REG_PORT}/v2/_catalog" | tr -d '\n'))"
else row registry "✘ not running (make up)"; fi
if cluster_exists; then row cluster "✔ $CTX"; else row cluster "✘ missing (make up)"; exit 0; fi
row "github trust" "$(saved_repo || true)"; [[ -n "$(saved_repo)" ]] || row "" "not configured (make oidc)"
kc get ns gatekeeper-system >/dev/null 2>&1 && row gatekeeper "✔ installed" || row gatekeeper "– not installed (make gatekeeper)"
pgrep -f "Runner.Listener" >/dev/null && row "self-hosted runner" "✔ running" || row "self-hosted runner" "– not running (make runner-start)"
for ns in dev prod; do
  img=$(kc -n "$ns" get deploy kubenotes -o jsonpath='{.spec.template.spec.containers[0].image}' 2>/dev/null || true)
  ready=$(kc -n "$ns" get deploy kubenotes -o jsonpath='{.status.readyReplicas}/{.spec.replicas}' 2>/dev/null || true)
  row "$ns" "${img:-not deployed}${ready:+  ready $ready}"
done
