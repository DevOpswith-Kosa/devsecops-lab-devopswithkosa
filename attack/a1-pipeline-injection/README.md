# A1 - Poisoned Pipeline Execution (CICD-SEC-4)

**Weakness:** `attack/workflows/90-chatops-vulnerable.yml` interpolates the
attacker-controlled issue **title** into a `run:` shell.

**Impact:** arbitrary commands on the **self-hosted runner** (your laptop),
with the admin kubeconfig in reach -> full cluster compromise.

**Do it:**
```bash
attack/attacker-box.sh start
# (no GitHub yet? see the mechanism first:)
attack/a1-pipeline-injection/prove-injection-locally.sh
# the real thing, once the repo + runner + workflow + secret are set up:
attack/a1-pipeline-injection/exploit.sh
attack/attacker-box.sh tail      # the kubeconfig arrives in attack/loot/
```

**Fixed by (Part 3):**
- never interpolate untrusted input into a shell (pass via `env:`) - Lab 13
- short-lived GitHub OIDC tokens instead of a stored admin kubeconfig - Lab 12
- least-privilege `GITHUB_TOKEN` and pinned actions - Lab 14
- `actionlint` + `zizmor` catch exactly this in CI - Lab 14, and Part 4 detection
