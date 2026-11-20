# 01 — A key in a commit

**Story.** A teammate hard-codes an AWS key "just to test", commits, and moves
on. It's now in history forever, even if the next commit removes it.

**Break.**
```bash
cat >> app/config_local.py <<'PY'
AWS_ACCESS_KEY_ID = "AKIAIOSFODNN7EXAMPLE"
AWS_SECRET_ACCESS_KEY = "wJalrXUtnFEMI/K7MDENG/bPxRfiCYEXAMPLEKEY"
PY
git add app/config_local.py && git commit -m "temp test config"
```

**Observe / catch it.**
```bash
make scan-secrets          # gitleaks scans the whole history, not just the diff
```
Gitleaks reports the file, line, and rule. In CI, `20-ci.yml` fails the push.

**Fix.** Remove it from history, not just the tip:
```bash
git rm app/config_local.py && git commit -m "remove secret"
# already pushed? rotate the key immediately and scrub history (git filter-repo).
```
Real secrets belong in a secret manager or, for the pipeline, in **OIDC
federation** (Lab 12) — a credential that never exists as a storable string.

**Why.** Secret scanning is the cheapest, highest-value gate. A leaked
long-lived key is exactly what Part 2's A1 attack stole — don't create ones to
steal.
