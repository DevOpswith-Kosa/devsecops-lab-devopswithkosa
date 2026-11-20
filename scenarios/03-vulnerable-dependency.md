# 03 — A library with a CVE

**Story.** `requirements.txt` pins a version that a CVE was later found in. The
code is fine; the dependency isn't.

**Break.** Pin an old, known-vulnerable Werkzeug:
```bash
sed -i.bak 's/^werkzeug==.*/werkzeug==2.0.0/' app/requirements.txt && rm -f app/requirements.txt.bak
```

**Observe / catch it.**
```bash
make scan-deps      # Trivy lists the CVE(s), the installed vs fixed version
```

**Fix.** Move to the fixed version (restore the pinned line) and rebuild:
```bash
git checkout app/requirements.txt
make build scan-image     # the image scan confirms it's clean
```

**Why.** You don't write most of your code — your dependencies do. SCA
(software composition analysis) is how you find the risk you inherited. Pair it
with Dependabot so upgrades arrive as PRs that re-run the whole pipeline.
