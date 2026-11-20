# 05 — A 2 a.m. hotfix by tag

**Story.** Prod is down. An engineer builds a quick fix and
`kubectl set image ...:hotfix` straight onto prod, skipping the pipeline. It
works tonight and becomes a habit. Now "what's in prod" is nobody-knows.

**Break (try the shortcut).**
```bash
kubectl --context kind-devsecops -n prod set image deploy/kubenotes app=localhost:5001/kubenotes:hotfix
```

**Observe / catch it.** With Gatekeeper's prod rule on (Lab 16), the API server
**refuses** any prod image that isn't a digest:
```bash
kubectl --context kind-devsecops -n prod apply -f platform/gatekeeper/examples/hotfix-by-tag.yaml   # denied: IMG-003
```

**Fix.** Ship the fix through the pipeline, which deploys by **digest** and
verifies the **signature**. If you truly need a break-glass path, make it an
audited, time-boxed one — not a mutable tag.

**Why.** This is Part 2's A3 attack wearing a friendly face. Immutable digests
+ admission control mean the only way into prod is the reviewed, scanned,
signed one.
