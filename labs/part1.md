# Part 1 — A plain CI/CD pipeline

**Goal:** get code from a commit to a running pod in kind, automatically. No
security gates yet. We build the "happy path" first so Part 2 has something
real to attack and Part 3 has something real to harden.

> **How to read these labs.** Each lab has a short *What you're doing / why*
> note, then a command block you can copy-paste, then *what you should see*.
> Run the commands in order, in your WSL/Linux/macOS terminal, from inside
> `~/devsecops-lab`. If anything errors, run `make doctor` first.

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
git clone https://github.com/DevOpswith-Kosa/devsecops-lab.git ~/devsecops-course
~/devsecops-course/scripts/new-lab-repo.sh ~/devsecops-lab
cd ~/devsecops-lab
gh repo create devsecops-lab --private --source . --push
```

- `git clone` downloads the course.
- `new-lab-repo.sh` copies it into `~/devsecops-lab` as a fresh git repo (no
  course history).
- `gh repo create … --source . --push` makes a **private** GitHub repo and
  pushes your copy to it.

From now on, work in `~/devsecops-lab`.

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
make runner-install REPO=<your-gh-user>/devsecops-lab
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
