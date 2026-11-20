#!/usr/bin/env bash
# Keyless-sign an image by digest with cosign, tying the signature to this
# repo's GitHub identity. Needs `id-token: write` and internet (Fulcio/Rekor).
#   ci/sign.sh localhost:5001/kubenotes@sha256:...
set -euo pipefail
ref="${1:?usage: sign.sh <image@sha256:...>}"
COSIGN_YES=true cosign sign --recursive "$ref"
echo "signed $ref"
