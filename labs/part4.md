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
