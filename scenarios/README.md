# Case scenarios

Short, self-contained stories you can run in any order **after** finishing the
labs. Each one follows the same shape:

> **Story** → **Break** (introduce a real problem) → **Observe** → **Which tool
> catches it** → **Fix** → **Why it matters**

They're how you *practise* what the labs taught: not "here is a control" but
"here is a Tuesday, something is wrong, find it and fix it". Great for a
workshop — hand one scenario per pair.

| # | Scenario | Theme | Catches it |
|---|----------|-------|-----------|
| 01 | [A key in a commit](01-leaked-secret.md) | secrets | Gitleaks |
| 02 | [The search box runs SQL](02-sql-injection.md) | SAST | Semgrep / Bandit + tests |
| 03 | [A library with a CVE](03-vulnerable-dependency.md) | SCA | Trivy (deps) |
| 04 | [It only works as root](04-root-container.md) | workload hardening | conftest + Pod Security |
| 05 | [A 2 a.m. hotfix by tag](05-latest-tag-hotfix.md) | artifact integrity | Gatekeeper + digests |
| 06 | [The leaked kubeconfig](06-stolen-kubeconfig.md) | identity | OIDC federation + RBAC |
| 07 | [An image nobody signed](07-unsigned-image.md) | supply chain | cosign verify |
| 08 | [The build broke at 2 a.m.](08-ai-build-failure.md) | AIOps | AI build doctor |
| 09 | [A shell in a pod](09-pod-exec-detected.md) | detection | audit log + AI incident |
| 10 | [A workflow that reads your secrets](10-workflow-injection.md) | pipeline security | actionlint / zizmor |

Each scenario is reversible — a `reset`/`git checkout` line restores the repo.
Run them against your lab cluster; if anything is stuck, `make down && make up`.
