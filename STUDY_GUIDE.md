# Study Guide — DevSecOps from zero, on your own machine

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

You install only **six** things. Every scanner (Trivy, Gitleaks, Semgrep, OPA,
ZAP, Kubescape, kube-bench…) runs as a container, so you never install those.

| Tool | What it is | Why you need it |
|------|-----------|-----------------|
| **Docker** | runs containers | the engine everything else rides on |
| **kind** | Kubernetes-in-Docker | your local cluster (no cloud) |
| **kubectl** | the Kubernetes client | you talk to the cluster with it |
| **git** | version control | the labs are a git repo |
| **make** | command runner | every lab step is a `make` target |
| **gh** | GitHub CLI | creates your repo, logs you in |

### Install

**macOS** (needs [Homebrew](https://brew.sh)):
```bash
brew install --cask docker        # then open Docker Desktop once, let it start
brew install kind kubectl git make gh
```

**Linux (Debian/Ubuntu):**
```bash
# docker: follow https://docs.docker.com/engine/install/ for your distro
sudo apt-get update && sudo apt-get install -y git make
# kind:
curl -Lo ./kind https://kind.sigs.k8s.io/dl/latest/kind-linux-amd64 && sudo install kind /usr/local/bin/
# kubectl:
curl -LO "https://dl.k8s.io/release/$(curl -L -s https://dl.k8s.io/release/stable.txt)/bin/linux/amd64/kubectl" && sudo install kubectl /usr/local/bin/
# gh: https://github.com/cli/cli#installation
```

**Windows:** use **WSL2** (Windows Subsystem for Linux) with Docker Desktop's
WSL integration turned on, then follow the **Linux** steps inside your WSL
terminal. Do not try to run the labs in PowerShell — they assume a Linux shell.

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
```

If any line errors, fix that one tool before moving on — Section 7 has help.

### (Optional) AI credential for Part 4

Part 4 uses Claude to triage findings and write incident reports. If you have
an `ANTHROPIC_API_KEY`, export it. **Without one you can still do Part 4** — the
AI tools print the exact prompt they *would* send, so you follow along and see
the inputs, just without the generated answer.

---

## 4. The one-time project setup (Labs 0–2)

GitHub only runs pipelines from the **root** of a repository, so your first job
is to turn this course folder into your own private repo.

```bash
# 1. Copy the track out into its own folder and make it a git repo
cicd/scripts/new-lab-repo.sh ~/devsecops-lab
cd ~/devsecops-lab

# 2. Create YOUR private GitHub repo and push to it
gh repo create devsecops-lab --private --source . --push

# 3. Bring up the local platform (registry + kind cluster) — takes 1–3 min
make up
make status
```

**You're done when** `make status` shows the registry and the cluster with a ✔,
and two namespaces (`dev`, `prod`) exist. That is your insecure baseline.

> **You can stop and resume any time.** `make down` deletes the cluster and
> registry (your files and repo are untouched). A clean restart is always
> `make down && make up`.

From here on, **always work inside `~/devsecops-lab`.**

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
| GitHub Actions won't run | workflows must be at the repo **root** | you ran `new-lab-repo.sh`? work inside `~/devsecops-lab`, not the subfolder |
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
