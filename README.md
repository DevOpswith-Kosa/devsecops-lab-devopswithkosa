# DevSecOps, end to end, on your own machine

Build a CI/CD pipeline, **break it like an attacker**, turn it into a
security-first DevSecOps pipeline, then make it **detect and respond** to the
next attack — with AI doing the triage. Everything runs locally on a real
Kubernetes cluster. No cloud account, no bill.

> **New here? Start with [`GUIDE.md`](GUIDE.md)** — the full student walkthrough
> of all four parts, including a step-by-step explanation of how each attack
> works. This README is the quick reference; `GUIDE.md` is the course.

```
 build  ─────────▶  attack  ─────────▶  govern  ─────────▶  detect & respond
 (Part 1)           (Part 2)           (Part 3)            (Part 4)
 plain CI/CD        own the pipeline   close every hole    audit log + AI
                    & the pod          OIDC · PSA · OPA    incident + build doctor
```

A student clones this into their own repo and works through **22 labs** and
**10 case scenarios**, guided at every step.

## Why it's built this way

- **Attack before defend.** You exploit the insecure pipeline (RCE on the
  runner → stolen cluster credential → pod takeover → image swap) *before* you
  learn the controls, so each control answers a real attack you've seen.
- **Real, never simulated.** A kind cluster, a local registry, a self-hosted
  runner, real scanners (Trivy, Gitleaks, Semgrep, OPA, ZAP), real admission
  control (Gatekeeper), real **OAuth2/OIDC federation** between GitHub and the
  Kubernetes API, real image signing (cosign).
- **CI == local.** Every gate is a `make` target that runs the same pinned
  container locally and in GitHub Actions. "Green on my laptop" means "green in
  CI".
- **AIOps that earns its place.** Claude diagnoses failed builds, prioritises
  scanner findings, and writes incident reports from the audit log — triage at
  machine speed, with the human still deciding.

## What a learner comes away knowing

- the full CI/CD lifecycle and where each stage is attacked (OWASP CI/CD Top 10);
- **security-first architecture**: least privilege, short-lived federated
  identity, immutable signed artifacts, admission control, defence in depth;
- **detection & response**: audit logging, runtime detection, and LLM-assisted
  triage and incident handling.

## Start here

**New to all of this? Read [`STUDY_GUIDE.md`](STUDY_GUIDE.md) first** — a
zero-knowledge, machine-agnostic walkthrough that takes you from an empty
laptop through all 22 labs, with per-OS setup, checkpoints, a troubleshooting
playbook, and a study schedule.

```bash
# copy the course into your own fresh git repo (workflows must live at the repo root)
NAME=yourname   # your first name, lowercase, e.g. alice
git clone https://github.com/DevOpswith-Kosa/devsecops-lab-devopswithkosa.git ~/devsecops-course
~/devsecops-course/scripts/new-lab-repo.sh ~/practice-lab-$NAME
cd ~/practice-lab-$NAME && gh repo create practice-lab-$NAME --private --source . --push
make doctor          # checks tools, versions, Docker, RAM and ports
make up              # local registry + kind cluster
```

See **[`docs/architecture.md`](docs/architecture.md)** for the pipeline
architecture — from the plain Part 1 flow to the full DevSecOps pipeline with
every gate.

Then open **[`labs/README.md`](labs/README.md)** and follow Part 1 → 4.
Browse **[`attack/`](attack/README.md)** for the red-team lab and
**[`scenarios/`](scenarios/README.md)** for break-fix-detect case studies.

## Tooling (all pinned in `tools.env`, all run as containers)

| Stage | Tool |
|-------|------|
| Secrets | Gitleaks |
| SAST | Semgrep, Bandit |
| SCA (dependencies & image) | Trivy + CycloneDX SBOM |
| IaC / Dockerfile / policy | Hadolint, Trivy config, OPA Conftest |
| K8s config posture | Kubescape (NSA + MITRE frameworks) |
| Cluster benchmark | kube-bench (CIS Kubernetes Benchmark) |
| Admission control | OPA Gatekeeper |
| Identity | GitHub OIDC → Kubernetes structured authentication (federation) |
| Supply chain | cosign (keyless sign + verify) |
| DAST | OWASP ZAP baseline |
| Pipeline security | actionlint, zizmor, pinned actions, least-priv tokens |
| Detection | Kubernetes API audit log, Gatekeeper audit, (optional) Falco |
| AIOps | Claude (`claude-opus-5-5`) build doctor, security triage, incident doctor |

You install only **docker, kind, kubectl, git, make, gh**.

## Prerequisites

Docker (Desktop or engine), ~8 GB RAM free, kind ≥ 0.33, kubectl, GitHub CLI.
For the AI labs, a Claude credential (`ANTHROPIC_API_KEY` or `ant auth login`) —
without one, the AI tools print the prompt they would send, so you can still
follow along.

---

Part of [KubeAcademy](../README.md). These are deliberately-vulnerable teaching
scenarios: run them only against your own local cluster.
