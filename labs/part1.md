# Part 1 — A plain CI/CD pipeline

**Goal:** get code from a commit to a running pod in kind, automatically. No
security gates yet. We build the "happy path" first so Part 2 has something
real to attack and Part 3 has something real to harden.

---

## Lab 0 — Prerequisites

You need these on your machine:

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

GitHub only runs workflows from the **root** of a repository, so copy this
course into a fresh repository of your own:

```bash
git clone https://github.com/DevOpswith-Kosa/devsecops-lab.git ~/devsecops-course
~/devsecops-course/scripts/new-lab-repo.sh ~/devsecops-lab
cd ~/devsecops-lab
gh repo create devsecops-lab --private --source . --push
```

From now on, work in `~/devsecops-lab`.

---

## Lab 2 — Bring up the platform

```bash
make up        # creates the local registry + the kind cluster (1–3 min)
make status
```

`make status` should show the registry and cluster as ✔. Two namespaces,
`dev` and `prod`, now exist with **no** security restrictions — that is the
insecure baseline Part 2 relies on.

Look at what `make up` did: `platform/up.sh`. Notice the cluster is created
with a fixed API address (`127.0.0.1:6443`) and an audit log — you'll use both
later.

---

## Lab 3 — Build, test and deploy by hand

Before automating, do it once yourself so the pipeline holds no mystery.

```bash
make test                     # pytest in a container
make build push               # build the image, push to localhost:5001, print its digest
make deploy-insecure          # apply the (insecure) Part 1 manifests to dev with YOUR kubeconfig
make status                   # dev should show the image and "ready 1/1"
curl localhost:8080/version   # the app, served from the cluster
curl -XPOST localhost:8080/api/notes -H 'content-type: application/json' -d '{"title":"hello"}'
curl localhost:8080/
```

Read `ci/render.sh` and `k8s/insecure/` to see exactly what was deployed.

> The Part 1 deployment (`k8s/insecure/`) is weak on purpose — root, writable
> filesystem, an over-privileged ServiceAccount token mounted in the pod, no
> limits, a mutable `:dev` tag. Every one of those is a door Part 2 walks
> through and Part 3 closes. Read the `(!)` comments in that file now.

---

## Lab 4 — Put a self-hosted runner on your machine

GitHub's cloud runners can't reach a cluster that only exists on your laptop.
A self-hosted runner can. (That convenience is also Part 2's first target.)

```bash
make runner-install REPO=<your-gh-user>/devsecops-lab
make runner-start
make status           # "self-hosted runner: ✔ running"
```

---

## Lab 5 — The automated pipeline (insecure)

`.github/workflows/10-ci-insecure.yml` is a working pipeline: test → build →
push → deploy to dev. It needs the cluster credential as a secret (we fix this
in Part 3 — for now it is a long-lived admin kubeconfig):

```bash
kubectl --context kind-devsecops config view --raw --minify --flatten \
  | gh secret set KUBECONFIG_ADMIN
```

Trigger it:

```bash
git commit --allow-empty -m "trigger the pipeline"
git push
gh run watch
```

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
