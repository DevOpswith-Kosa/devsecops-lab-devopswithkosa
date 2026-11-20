# Part 2 — Attack the pipeline (red team)

> **Only ever against your own cluster.** Everything here targets your kind
> cluster and a listener on `127.0.0.1`. Nothing leaves your machine. You do
> this to understand the defences in Part 3 — read `attack/README.md` first.

You have a working pipeline. Now prove it isn't safe. Three attacks, each
mapping to an OWASP CI/CD risk, each fixed later.

Start the stand-in "attacker server" (local loot box):

```bash
attack/attacker-box.sh start      # listens on 127.0.0.1:9000, saves to attack/loot/
```

---

## Lab 6 — See the injection mechanism (no GitHub needed)

The vulnerable ChatOps workflow drops an issue **title** into a shell. Prove
the breakout locally first — this runs the *exact* vulnerable shell line:

```bash
cat attack/a1-pipeline-injection/payload.txt
attack/a1-pipeline-injection/prove-injection-locally.sh
```

See how `/status"; <commands> ; echo "` escapes the `echo` and runs commands.
That is **script injection** (OWASP CICD-SEC-4).

---

## Lab 7 — Arm the vulnerable workflow

Copy the deliberately-vulnerable workflow into place and push it:

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

Open the malicious issue. The self-hosted runner executes the payload and
exfiltrates the admin kubeconfig to your loot box:

```bash
attack/a1-pipeline-injection/exploit.sh     # opens the crafted issue via gh
attack/attacker-box.sh tail                 # watch the kubeconfig arrive
ls attack/loot/                             # the stolen credential
```

You (as the attacker) now hold a **full cluster-admin kubeconfig** that never
expires. This is the worst case, and it came from one issue title.

Save the stolen kubeconfig to use as the attacker:

```bash
cp attack/loot/*kubeconfig* /tmp/stolen-kubeconfig
```

---

## Lab 9 — A2: own the workload and the namespace

Use the stolen credential to attack the running pod. The Part 1 deployment
runs as root, has a writable filesystem, and mounts an over-privileged
ServiceAccount token:

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

The pipeline deploys the **mutable** `:dev` tag. Anyone who can push to the
registry can replace what runs — no PR, no pipeline, no trace:

```bash
attack/a3-image-tampering/exploit.sh dev
```

It builds a backdoored image, pushes it over `:dev`, restarts the deployment,
and proves the running pod is now the attacker's build. This is why "deploy by
tag" is unsafe and why Part 3 deploys by **digest** and **verifies a
signature**.

---

## Clean up

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
