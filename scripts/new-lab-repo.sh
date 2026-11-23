#!/usr/bin/env bash
# Copy this track into its own folder as a fresh git repository, ready to
# push to YOUR GitHub account. GitHub only runs workflows from the root of a
# repository, so each learner gets a fresh repo with clean history.
#   scripts/new-lab-repo.sh ~/devsecops-lab
set -euo pipefail
src="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
dest="${1:-$HOME/devsecops-lab}"
if [[ -e "$dest" && "$(cd "$dest" && pwd)" == "$src" ]]; then
  echo "x $dest is this course folder itself. Copy it somewhere else, e.g.:" >&2
  echo "    $0 ~/my-devsecops-lab" >&2
  exit 1
fi
[[ -e "$dest" ]] && { echo "x $dest already exists. Pick another folder or delete it." >&2; exit 1; }
mkdir -p "$dest"
# Copy everything except generated or machine-specific files.
( cd "$src" && tar --exclude='./.local' --exclude='./reports' \
    --exclude='./platform/runner/actions-runner' \
    --exclude='./k8s/.render.*' --exclude='__pycache__' -cf - . ) | ( cd "$dest" && tar -xf - )
cd "$dest"
git init -q -b main
git add -A
git commit -q -m "Start the DevSecOps lab" || true
echo "Created $dest (branch main)"
echo
echo "Next:"
echo "  cd $dest"
echo "  gh repo create devsecops-lab --private --source . --push"
echo "  then open labs/README.md"
