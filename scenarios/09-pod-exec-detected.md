# 09 — A shell in a pod

**Story.** Someone (or something) opens an interactive shell inside a running
pod. Maybe it's an engineer debugging; maybe it's an intruder. Either way you
want to know.

**Break (generate the signal).**
```bash
kubectl --context kind-devsecops -n dev exec deploy/kubenotes -- id
```

**Detect.**
```bash
make detect        # RUNTIME-EXEC (critical) in detect/findings.json
make incident      # AI incident report: what, blast radius, contain, prevent
```

**Respond.** The report's containment steps (cordon the workload, rotate
anything the pod could reach, check for rogue pods) plus the root cause (should
this pod even allow exec? is there a token inside it?).

**Why.** Prevention isn't enough; you need the **record** and a fast read of
it. The API audit log is that record; the detector and AI make it legible.
Add Falco (`detect/falco/`) to catch the same shell at the syscall level.
