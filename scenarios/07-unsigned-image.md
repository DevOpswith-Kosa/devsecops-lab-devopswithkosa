# 07 — An image nobody signed

**Story.** An image appears in the registry under the right name. Did your
pipeline build it, or did someone push it by hand?

**Break.**
```bash
docker tag localhost:5001/kubenotes:dev localhost:5001/kubenotes:rogue
docker push localhost:5001/kubenotes:rogue
```

**Observe / catch it.** CD verifies the signature before deploying:
```bash
ci/verify.sh localhost:5001/kubenotes:rogue "$(gh repo view --json nameWithOwner -q .nameWithOwner)"   # FAILS: not signed by your repo
```

**Fix.** Only deploy images your pipeline **keyless-signed** (`ci/sign.sh`,
tied to your repo's GitHub identity). Gatekeeper's digest rule plus signature
verification means an unsigned or foreign image can't run.

**Why.** Supply-chain integrity: "it's in our registry" is not "we made it".
Signing binds the artifact to the identity and workflow that produced it.
