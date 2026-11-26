# DevSecOps on a real cluster — the labs

You will build a CI/CD pipeline, **attack it**, then make it a DevSecOps
pipeline, then make it **detect** the next attack — all on your own laptop.
The app is a tiny notes API (`app/`); the point is everything around it.

Everything runs locally: a [kind](https://kind.sigs.k8s.io) Kubernetes
cluster, a local container registry, and a self-hosted GitHub Actions runner.
Every scanner runs as a pinned container, so the only things you install are
**docker, kind, kubectl, git, make** (and `gh` for the GitHub parts).

## The four parts

| Part | You play | You learn | Folder |
|------|----------|-----------|--------|
| 1 | Platform engineer | a plain CI/CD pipeline: test → build → push → deploy to kind | `labs/part1.md` |
| 2 | **Attacker** | how that pipeline and deployment get owned (RCE, stolen creds, pod takeover, image swap) | `labs/part2.md` + `attack/` |
| 3 | DevSecOps engineer | shift-left scans, OIDC federation, Pod Security, OPA/Gatekeeper, signing — each closes a Part 2 attack | `labs/part3.md` |
| 4 | SRE / responder | audit logging, runtime detection, and **AI** that diagnoses builds and incidents | `labs/part4.md` |

The order matters: you can't appreciate a control until you've seen the
attack it stops, and you can't trust a control until something tells you when
it's bypassed.

## Outcomes

By the end you can explain and demonstrate, hands-on:

- a complete CI/CD flow and where each stage can be subverted (OWASP CICD Top 10);
- **security-first architecture**: least privilege, short-lived identity
  (OAuth2/OIDC federation), immutable artifacts, admission control, defence in depth;
- **AIOps**: using an LLM to triage failures, prioritise findings, and respond to incidents.

## Setup (once)

```bash
# 1. Prerequisites
labs/part1.md   # step 0 lists them and checks your machine

# 2. Make this your own repository (GitHub won't run workflows from a subfolder)
NAME=yourname   # your first name, lowercase, e.g. alice
git clone https://github.com/DevOpswith-Kosa/devsecops-lab-devopswithkosa.git ~/devsecops-course
~/devsecops-course/scripts/new-lab-repo.sh ~/practice-lab-$NAME
cd ~/practice-lab-$NAME
gh repo create practice-lab-$NAME --private --source . --push

# 3. Bring up the platform
make doctor   # fix anything it marks with ✘
make up
make status
```

Then open **`labs/part1.md`** and go.

> **Tear down anytime:** `make down` deletes the cluster and registry. Your
> repo and files are untouched. A fresh start is always `make down && make up`.

## Map of the repo

```
app/            the notes API + Dockerfile + tests
k8s/base,overlays   hardened Kubernetes manifests (Part 3)
k8s/insecure/   the deliberately-weak Part 1 deployment (Part 2 targets it)
platform/       scripts: kind, registry, OIDC trust, Gatekeeper, audit, runner
ci/             render-by-digest, OIDC kubeconfig, cosign sign/verify
policies/       OPA/Rego policies (conftest, with unit tests)
.github/workflows/  the pipelines (10 insecure, 20 CI, 21 CD, 30 AI doctor)
attack/         the red-team lab (Part 2)
detect/         the audit-log detector (Part 4)
ai/             the Claude-powered build/security/incident tools (Part 4)
scenarios/      self-contained break-fix-detect case studies
docs/           architecture.md: the begin → final pipeline diagrams
Makefile        every command the pipeline runs, runnable locally
```

> New to the big picture? Read **[`docs/architecture.md`](../docs/architecture.md)**
> first — it draws the plain Part 1 pipeline and the full DevSecOps pipeline
> with every gate (including Kubescape config scanning, the CIS benchmark, and
> DAST) side by side.
