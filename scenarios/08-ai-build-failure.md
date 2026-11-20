# 08 — The build broke at 2 a.m.

**Story.** The pipeline goes red overnight. The on-call engineer doesn't want to
read 600 lines of CI log to find the one that matters.

**Break (any real failure works).**
```bash
make scan 2>&1 | tee reports/build.log || true
```

**Respond with AI.**
```bash
make ai-doctor LOG=reports/build.log
```
The build doctor names the failing step, the root cause, a copy-pasteable fix,
and one change to prevent a repeat. If the "failure" is a scanner catching a
real problem, it says so — the fix is the code, not the gate. In GitHub,
`30-ai-build-doctor.yml` posts this automatically on any CI failure.

**Why.** AIOps isn't magic; it's triage at machine speed. The human still
decides — they just start from an explanation instead of a log.
