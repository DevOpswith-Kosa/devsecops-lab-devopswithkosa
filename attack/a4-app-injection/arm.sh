#!/usr/bin/env bash
# Arm Lab A4: plant the insecure debug/search routes into the app, then rebuild
# and redeploy the INSECURE Part 1 workload (which sets INSECURE_MODE=1). After
# this, attack/a4-app-injection/exploit.sh works against the running pod.
#
# Part 3 un-arms it:  rm app/insecure_demo.py  (and deploy the hardened workload)
set -euo pipefail
HERE="$(cd "$(dirname "$0")" && pwd)"
ROOT="$(cd "$HERE/../.." && pwd)"
cd "$ROOT"

cp "$HERE/insecure_demo.py" app/insecure_demo.py
echo "planted app/insecure_demo.py (RCE + SQLi), gated by INSECURE_MODE=1"

make build push
make deploy-insecure
echo
echo "armed. now run:  attack/a4-app-injection/exploit.sh"
echo "note: 'make scan-sast' will now FAIL on app/insecure_demo.py -- that is"
echo "      the Part 3 lesson. Un-arm with:  rm app/insecure_demo.py"
