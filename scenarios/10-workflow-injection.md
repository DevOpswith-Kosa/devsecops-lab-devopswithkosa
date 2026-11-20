# 10 — A workflow that reads your secrets

**Story.** A convenient workflow interpolates a PR title / issue body / branch
name into a shell "to be helpful". That's remote code execution on your runner.

**Break.** Copy the vulnerable workflow in:
```bash
cp attack/workflows/90-chatops-vulnerable.yml .github/workflows/
```

**Observe / catch it.**
```bash
make scan-workflows     # zizmor: "template-injection"; actionlint: "potentially untrusted"
```
The scanner points at the exact line where `${{ github.event.issue.title }}`
meets the shell.

**Fix.** Pass untrusted input through `env:` and reference it as `"$VAR"`, so
the shell treats it as data, never code. Pin actions to a SHA, make the default
token read-only, and keep secrets out of jobs that handle untrusted input.
Remove the bot:
```bash
rm .github/workflows/90-chatops-vulnerable.yml
```

**Why.** The pipeline is software too, and a high-value target (Part 2, A1).
`actionlint` + `zizmor` are SAST for your pipeline — run them as a gate.
