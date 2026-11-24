# Part 2 — Attack the pipeline (red team)

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
