# Part 2 - The attack lab (red team)

> **Scope and safety.** Everything here runs against **your own** kind cluster,
> your own registry and a listener on **127.0.0.1**. Nothing leaves your
> machine. This exists to teach defence: you break the Part 1 pipeline so that
> Part 3's hardening and Part 4's detection mean something. Don't point these
> techniques at anything you don't own.

Part 1 gave you a pipeline that *works*. This part shows why "it works" is not
the same as "it's safe". You play the attacker against the insecure pipeline
and the insecure deployment, then Part 3 closes each hole and Part 4 catches
the next attempt.

## The three attacks

| # | Name | OWASP CICD | What it abuses | Folder |
|---|------|-----------|----------------|--------|
| A1 | Poisoned pipeline execution | SEC-4 | issue title → shell on the self-hosted runner → steal the admin kubeconfig | `a1-pipeline-injection/` |
| A2 | Workload & namespace takeover | SEC-6 | root pod + mounted over-privileged ServiceAccount token | `a2-pod-compromise/` |
| A3 | Supply-chain tag mutation | SEC-5 | deploy uses a mutable `:dev` tag, not a digest | `a3-image-tampering/` |

They chain: **A1** steals the cluster credential, **A2** uses it to own the
workload and the namespace, **A3** shows you don't even need the pipeline once
tags are mutable.

## Running order (full detail in `labs/part2/`)

```bash
attack/attacker-box.sh start          # the "attacker's server" (localhost)

# A1 - pipeline injection
attack/a1-pipeline-injection/prove-injection-locally.sh   # see the mechanism
attack/a1-pipeline-injection/exploit.sh                   # the real thing via GitHub
attack/attacker-box.sh tail                               # watch the loot arrive

# A2 - pod compromise (use the stolen kubeconfig, or admin while learning)
attack/a2-pod-compromise/exploit.sh ~/.kube/config dev

# A3 - image tampering
attack/a3-image-tampering/exploit.sh dev

attack/reset.sh                       # undo the attack artifacts
attack/attacker-box.sh stop
```

## Every attack maps to a fix

| Attack | Governed / fixed in Part 3 | Detected in Part 4 |
|--------|---------------------------|--------------------|
| A1 injection | env-pass untrusted input, OIDC not kubeconfig, pinned actions, least-priv token (Labs 12-14) | `actionlint`/`zizmor` gate; audit log shows the token use |
| A2 pod takeover | non-root + read-only FS, drop the SA token, tight RBAC, Pod Security, Gatekeeper (Labs 11, 15, 16) | audit log flags `pods/exec` and secret reads; Gatekeeper audit |
| A3 tag swap | deploy by digest, cosign sign+verify, Gatekeeper digest rule (Labs 10, 16, 17) | signature verify fails; admission denies a non-digest image |

When you reach Part 4, come back and run each attack again — this time the
pipeline refuses it, or the detector pages you.
