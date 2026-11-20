# Part 3 — Make it a DevSecOps pipeline

Now close every door Part 2 walked through. Each lab is one control. Run the
matching attack again after each one and watch it fail.

Everything here is a `make` target that runs the **same** containerised
scanner locally and in CI, so "green on my laptop" means "green in the
pipeline".

---

## Lab 11 — Harden the workload

Compare `k8s/insecure/deployment.yaml` with `k8s/base/deployment.yaml`. The
hardened one: runs as a fixed non-root user, read-only root filesystem, drops
**all** capabilities, no privilege escalation, a seccomp profile, resource
limits, probes, a NetworkPolicy, and — crucially — `automountServiceAccount
Token: false`, so there is **no token in the pod** for an attacker to steal.

```bash
make deploy ENV=dev            # now deploys k8s/overlays/dev (the hardened set)
# re-run A2 against it:
attack/a2-pod-compromise/exploit.sh ~/.kube/config dev
```

A2 now stalls: `id` shows a non-root user, there is no SA token to read, the
root filesystem is read-only. **Defence in depth** — several small limits, each
removing one of the attacker's moves.

---

## Lab 12 — Replace the stolen-able kubeconfig with OIDC federation

This is the fix for A1's worst outcome. Instead of a long-lived admin
kubeconfig in a GitHub secret, the cluster **trusts GitHub's OIDC issuer** and
accepts short-lived, scoped tokens — OAuth2/OIDC **federation**.

```bash
make oidc REPO=<your-gh-user>/devsecops-lab
```

Read what it did (`platform/oidc.sh`, `platform/auth/auth-config.yaml.tpl`):
the API server now validates a GitHub-signed JWT, checks it was minted for
this cluster, that it comes from **your** repo on **main** bound to the **dev**
or **prod** environment, and maps it to a Kubernetes user with a
**least-privilege** Role (`platform/rbac/ci-deployer.yaml.tpl`) in that one
namespace. A `dev` token cannot touch `prod`.

Publish the (public, non-secret) connection details as repo variables:

```bash
make oidc-vars           # sets KIND_API_SERVER, KIND_AUDIENCE, KIND_CA_DATA
```

There is now **no cluster credential to steal** — tokens live for minutes and
only work from your pipeline. Delete the old secret:

```bash
gh secret delete KUBECONFIG_ADMIN
```

---

## Lab 13 — Remove the injection, fix the input handling

Delete the vulnerable ChatOps workflow — the fixed pipeline never needs a
pattern like it:

```bash
git rm .github/workflows/90-chatops-vulnerable.yml
git commit -m "remove vulnerable chatops bot"
```

The rule it broke: **never interpolate untrusted input (`${{ github.event.*
}}`) into a shell**. Pass it through `env:` instead, where the shell treats it
as data. The secure workflows in `.github/workflows/20-ci.yml` and `21-cd.yml`
do exactly this.

---

## Lab 14 — Turn on the scans and secure the pipeline itself

Run every shift-left gate locally:

```bash
make scan            # gitleaks (secrets) + semgrep/bandit (SAST) + trivy (SCA) + hadolint/trivy/conftest (IaC & policy)
make policy-test     # unit tests for the OPA policies
make scan-workflows  # actionlint + zizmor on the workflows themselves
```

`scan-workflows` flags the **insecure** Part 1 pipeline (unpinned actions,
over-broad token). Replace it: the secure `20-ci.yml` runs all these gates on
every push and PR, and `21-cd.yml` deploys over OIDC by digest.

```bash
git rm .github/workflows/10-ci-insecure.yml
git add .github/workflows/20-ci.yml .github/workflows/21-cd.yml
git commit -m "secure CI/CD: scans + OIDC deploy"
git push
gh run watch
```

Notice the secure workflows **pin actions to a commit SHA**, use a
**read-only** default token, request `id-token: write` only where needed, and
set `persist-credentials: false`.

---

## Lab 15 — Enforce Pod Security

Make the API server refuse an insecure pod at admission, cluster-wide:

```bash
platform/psa-restricted.sh                                       # labels dev/prod "restricted"
kubectl --context kind-devsecops -n dev apply -f k8s/insecure/   # now REJECTED
```

The insecure Part 1 deployment no longer fits. Good.

---

## Lab 16 — Admission policy with OPA Gatekeeper

Pod Security covers the pod. Gatekeeper covers everything else — where images
may come from, no `:latest`, required limits, and (in prod) **digests only**,
so nobody can `kubectl set image ...:hotfix` around the pipeline (A3).

```bash
make gatekeeper
# try the hand-made "hotfixes" Gatekeeper should refuse:
kubectl --context kind-devsecops -n dev  apply -f platform/gatekeeper/examples/sneaky-pod.yaml
kubectl --context kind-devsecops -n prod apply -f platform/gatekeeper/examples/hotfix-by-tag.yaml
```

Both are denied, with the policy id in the message. The same rules run
**shift-left** in CI via `conftest` (`make scan-iac`), so a bad manifest fails
the PR long before admission.

---

## Lab 17 — Sign and verify images

Close A3 completely. CI **keyless-signs** each image by digest, tied to your
repo's GitHub identity (`ci/sign.sh`); CD **verifies** that signature before
deploying (`ci/verify.sh`). An unsigned or foreign image fails verification
and never reaches the cluster.

```bash
# (runs in CI; to try locally you need cosign + internet for Fulcio/Rekor)
cosign version
```

---

### What you built: security-first architecture

| Attack (Part 2) | Control (Part 3) | Lab |
|-----------------|------------------|-----|
| A1 injection | env-pass input, pinned actions, least-priv token | 13, 14 |
| A1 stolen kubeconfig | OIDC federation, short-lived scoped tokens | 12 |
| A2 pod takeover | non-root, read-only FS, no SA token, tight RBAC | 11 |
| A2 any insecure pod | Pod Security `restricted` | 15 |
| A2 bad deploy by hand | Gatekeeper admission + conftest shift-left | 16 |
| A3 image swap | deploy by digest, cosign sign + verify | 16, 17 |

→ Continue to **`labs/part4.md`** to catch the next attempt.
