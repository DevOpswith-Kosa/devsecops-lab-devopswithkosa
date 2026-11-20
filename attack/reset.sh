#!/usr/bin/env bash
# Undo what the attack lab created, so you can replay it or move on cleanly.
set -uo pipefail
CTX="kind-devsecops"
kubectl --context "$CTX" -n dev delete pod rogue-miner --ignore-not-found 2>/dev/null || true
kubectl --context "$CTX" -n prod delete pod rogue-miner --ignore-not-found 2>/dev/null || true
POD="$(kubectl --context "$CTX" -n dev get pods -l app.kubernetes.io/name=kubenotes -o jsonpath='{.items[0].metadata.name}' 2>/dev/null || true)"
[[ -n "$POD" ]] && kubectl --context "$CTX" -n dev exec "$POD" -- rm -f /owned.txt /BACKDOOR 2>/dev/null || true
rm -f loot/*.txt 2>/dev/null || true
echo "attack artifacts cleared (rogue pod, marker files, loot/)."
echo "to rebuild a clean image over the :dev tag, re-run the Part 1 pipeline or:"
echo "  docker build -t localhost:5001/kubenotes:dev app && docker push localhost:5001/kubenotes:dev"
