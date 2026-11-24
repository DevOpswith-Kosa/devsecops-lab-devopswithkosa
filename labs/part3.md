# Part 3 — Make it a DevSecOps pipeline

Now close every door Part 2 walked through. **Each lab is one control**, and
each control maps to an attack you just ran — after each one, re-run the
matching attack and watch it fail.

Everything here is a `make` target that runs the **same** containerised
scanner locally and in CI, so "green on my laptop" means "green in the
pipeline".

> **The tools you'll meet in this part** (all run as containers — nothing to
> install except cosign):
>
> | Tool | Kind of check | What it looks at |
> |---|---|---|
> | **Gitleaks** | secrets | passwords/keys anywhere in git history |
> | **Semgrep / Bandit** | SAST (static code) | insecure code patterns |
> | **Trivy** | SCA + image + config | known CVEs in deps & image, misconfig |
> | **Hadolint** | lint | Dockerfile mistakes |
> | **Conftest / OPA** | policy | your own rules on the manifests |
> | **Gatekeeper** | admission | blocks bad resources *at* the cluster |
> | **Kubescape** | benchmark | manifests vs NSA-CISA + MITRE |
> | **kube-bench** | benchmark | the cluster vs the CIS Benchmark |
> | **cosign** | signing | proves an image came from your pipeline |
> | **OWASP ZAP** | DAST (dynamic) | the *running* app over HTTP |
>
> "Shift-left" means running a check early (on your laptop / in CI) instead of
> waiting for something to go wrong in production.

---

## Lab 11 — Harden the workload  *(closes A2)*

**What you're doing:** switching from the insecure Part 1 deployment to the
hardened one, and re-running the A2 attack to watch it fail.

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

`make deploy` deploys the app **by digest** (the exact image fingerprint, not a
movable tag). If the image for your current commit isn't built yet, it builds
and pushes it first, so this works on its own.

A2 now stalls: `id` shows a non-root user, there is no SA token to read, the
root filesystem is read-only. **Defence in depth** — several small limits, each
removing one of the attacker's moves.

---

## Lab 12 — Replace the stolen-able kubeconfig with OIDC federation  *(closes A1's prize)*

**What you're doing:** removing the thing A1 stole. **OIDC federation** means the
cluster trusts GitHub's identity provider directly, so your pipeline proves who
it is with a **short-lived token** instead of a stored admin kubeconfig.

```bash
make oidc REPO=<your-gh-user>/devsecops-lab
```

Read what it did (`platform/oidc.sh`, `platform/auth/auth-config.yaml.tpl`):
the API server now validates a GitHub-signed JWT (a signed token), checks it was
minted for this cluster, that it comes from **your** repo on **main** bound to
the **dev** or **prod** environment, and maps it to a Kubernetes user with a
**least-privilege** Role (`platform/rbac/ci-deployer.yaml.tpl`) in that one
namespace. A `dev` token cannot touch `prod`.

Publish the (public, non-secret) connection details as repo variables so the
pipeline can find the cluster:

```bash
make oidc-vars           # sets KIND_API_SERVER, KIND_AUDIENCE, KIND_CA_DATA
```

There is now **no cluster credential to steal** — tokens live for minutes and
only work from your pipeline. Delete the old secret:

```bash
gh secret delete KUBECONFIG_ADMIN
```

---

## Lab 13 — Remove the injection, fix the input handling  *(closes A1)*

**What you're doing:** deleting the vulnerable ChatOps workflow. The fixed
pipeline never needs a pattern like it.

```bash
git rm .github/workflows/90-chatops-vulnerable.yml
git commit -m "remove vulnerable chatops bot"
```

The rule it broke: **never interpolate untrusted input (`${{ github.event.*
}}`) into a shell**. Pass it through `env:` instead, where the shell treats it
as data, not code. The secure workflows waiting in `ci/workflows/20-ci.yml` and
`21-cd.yml` do exactly this.

---

## Lab 14 — Turn on the scans and secure the pipeline itself

**What you're doing:** running every static security gate on your laptop, then
replacing the insecure pipeline with the secure one that runs those same gates
on every push.

```bash
make scan            # gitleaks (secrets) + semgrep/bandit (SAST) + trivy (SCA) + hadolint/trivy/conftest (IaC & policy)
make policy-test     # unit tests for the OPA policies
make scan-workflows  # actionlint + zizmor on the workflows themselves
```

What you're seeing: `make scan` runs four kinds of check in order — **secrets**
(Gitleaks), **code** (Semgrep/Bandit), **dependencies** (Trivy), and
**manifests/Dockerfile** (Hadolint/Trivy/Conftest). On the hardened code they
all pass. `scan-workflows` checks the workflow files themselves and flags the
**insecure** Part 1 pipeline (unpinned actions, over-broad token).

> **See SAST earn its keep.** If you armed the Part 2 app attack (Lab 10b) and
> left `app/insecure_demo.py` in place, `make scan-sast` **fails** — Semgrep and
> Bandit flag the `shell=True` command injection and the raw-SQL query. That is
> shift-left working: the A4 RCE/SQLi is caught on your laptop, before it ships.
> The fix is to delete the debug route (`rm -f app/insecure_demo.py`); the
> parameterised query in `app.py` already handles safe search.

Now replace the insecure pipeline. The secure `20-ci.yml` runs all these gates
on every push and PR, and `21-cd.yml` deploys over OIDC by digest:

```bash
git rm .github/workflows/10-ci-insecure.yml
cp ci/workflows/20-ci.yml ci/workflows/21-cd.yml .github/workflows/
git add .github/workflows/
git commit -m "secure CI/CD: scans + OIDC deploy"
git push
gh run watch
```

Notice the secure workflows **pin actions to a commit SHA**, use a
**read-only** default token, request `id-token: write` only where needed, and
set `persist-credentials: false`.

---

## Lab 15 — Enforce Pod Security  *(closes A2 for any pod)*

**What you're doing:** telling the cluster to refuse insecure pods *at
admission* — before they ever run — using Kubernetes' built-in **Pod Security**
standard, cluster-wide.

```bash
platform/psa-restricted.sh                                       # labels dev/prod "restricted"
kubectl --context kind-devsecops -n dev apply -f k8s/insecure/   # now rejected
```

The second command tries to apply the insecure Part 1 manifest again. You'll see
a **PodSecurity "restricted" violation** listing exactly what's wrong
(`runAsNonRoot`, `allowPrivilegeEscalation`, capabilities, seccomp). The pod no
longer fits — which is the point. (The hardened deployment still runs fine.)

---

## Lab 16 — Admission policy with OPA Gatekeeper  *(closes A2 rogue pods, A3)*

**What you're doing:** adding **Gatekeeper**, a policy engine that inspects every
resource as it's created and denies the ones that break your rules. Pod Security
covers the pod; Gatekeeper covers everything else — where images may come from,
no `:latest`, required limits, and (in prod) **digests only**, so nobody can
`kubectl set image ...:hotfix` around the pipeline (A3).

```bash
make gatekeeper
# try the hand-made "hotfixes" Gatekeeper should refuse:
kubectl --context kind-devsecops -n dev  apply -f platform/gatekeeper/examples/sneaky-pod.yaml
kubectl --context kind-devsecops -n prod apply -f platform/gatekeeper/examples/hotfix-by-tag.yaml
```

Both are **denied**, with the policy id in the message — e.g. `[only-local-registry]`,
`[no-latest-tag]`, `[require-limits]` for the sneaky pod, and `[prod-digest-only]`
for the tag hotfix. The same rules run **shift-left** in CI via `conftest`
(`make scan-iac`), so a bad manifest fails the PR long before admission.

---

## Lab 16b — Measure against the standards: Kubescape + CIS benchmark

**What you're doing:** Conftest and Gatekeeper enforce **your** rules. Now you
measure against **industry standards** — the gap you can't see is the one that
gets you. A *benchmark* scores you against a published security standard.

**Kubescape — scan the manifests (shift-left, no cluster):**

```bash
make scan-config        # k8s/base against the NSA-CISA + MITRE frameworks
```

The hardened base passes. Now watch the insecure Part 1 manifest fail the same
frameworks:

```bash
docker run --rm -v "$PWD:/src" -w /src quay.io/kubescape/kubescape-cli:v4.0.21 \
  scan framework nsa,mitre k8s/insecure --format pretty-printer
```

This is what Kubescape adds over conftest: findings mapped to **NSA-CISA**
hardening guidance and **MITRE ATT&CK** techniques, not just pass/fail. It runs
in CI (`20-ci.yml`), so a weak manifest fails the PR.

**kube-bench — benchmark the running cluster (CIS):**

```bash
make cis                # runs kube-bench as a Job against the kind node
```

You'll see `[PASS]`, `[WARN]` and `[FAIL]` lines against the **CIS Kubernetes
Benchmark** (and a summary like "65 checks PASS, 11 FAIL, 55 WARN"). kind is a
developer cluster, not a hardened distribution, so there are real FAILs — that
is the lesson. A benchmark measures the distance between what you run and the
standard. Read `reports/kube-bench.txt` and pick three findings you'd fix on a
production cluster.

---

## Lab 17 — Sign and verify images  *(closes A3)*

**What you're doing:** making images tamper-evident. **cosign** cryptographically
**signs** each image, tying it to your repo's GitHub identity; the deploy step
**verifies** that signature first. An unsigned or foreign image (like A3's
backdoor) fails verification and never reaches the cluster.

CI signs by digest (`ci/sign.sh`) and CD verifies before deploying
(`ci/verify.sh`). "Keyless" means there's no private key to manage — cosign uses
a short-lived certificate tied to the workflow's identity. Locally you can just
confirm the tool is present (real signing needs the pipeline + internet):

```bash
# (runs in CI; to try locally you need cosign + internet for Fulcio/Rekor)
cosign version
```

---

## Lab 17b — Dynamic scan the running app (DAST)

**What you're doing:** scanning the *running* app from the outside. Every scan so
far was **static** (it read code, manifests, the image). **DAST** (Dynamic
Application Security Testing) is different: **OWASP ZAP** drives the live app
over HTTP, like an attacker with no source access, and reports what it finds
(missing security headers, exposed endpoints, injection responses).

```bash
make build push
make deploy ENV=dev          # hardened, deploy-by-digest
make dast ENV=dev            # OWASP ZAP baseline against the app in dev
```

ZAP crawls the service in the cluster and writes `reports/zap-report.html`
(open it in a browser). It takes a few minutes. Because Part 3 hardened the app
(security headers, locked-down responses), the baseline comes back **clean** —
compare that to running it against the Part 1 app. DAST is the complement to
SAST: static scanning proves the code *looks* right, DAST proves the deployed
app *behaves* right.

> Static (SAST/SCA/IaC/config) → build → sign → admission → **DAST on the live
> app** → detection. Each layer sees something the others can't.

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
| A4 app RCE + SQLi | SAST catches it (14), no debug route, no token in pod (11) | 11, 14 |
| gap vs. standards | Kubescape (NSA/MITRE) + kube-bench (CIS Benchmark) | 16b |
| vulnerable running app | OWASP ZAP dynamic scan (DAST) | 17b |

→ Continue to **`labs/part4.md`** to catch the next attempt.
