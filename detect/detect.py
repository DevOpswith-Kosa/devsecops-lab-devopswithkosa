#!/usr/bin/env python3
"""Part 4 -- turn the Kubernetes API audit log into findings.

Reads the audit log the cluster writes (platform wires it up in up.sh) and
flags the exact moves the attack lab makes: a shell opened in a pod, Secrets
read, rogue pods created, RBAC changed, and a pipeline identity acting in the
wrong environment.

  detect/detect.py [--audit-log .local/audit/audit.log] [--json detect/findings.json]

No cluster call and no dependencies -- just the log. Exit code is the number
of findings (capped at 250), so CI or a cron can act on it.
"""
from __future__ import annotations

import argparse
import json
import sys
from collections import Counter
from pathlib import Path

SEV = {"critical": 3, "high": 2, "medium": 1, "info": 0}


# Kubernetes' own control-plane identities. Their routine reads/writes are not
# an incident; an attacker shows up as a user, a pod ServiceAccount, or a
# pipeline identity, which are NOT in this set.
PLATFORM = {"system:apiserver", "system:kube-controller-manager",
            "system:kube-scheduler", "system:kube-proxy"}
# The cluster bootstraps itself as these at creation time (kubeadm). Their
# writes in the system namespaces are setup, not an attack.
BOOTSTRAP = {"kubernetes-admin", "kubernetes-super-admin"}
SYSTEM_NS = {"kube-system", "kube-public", "kube-node-lease",
             "local-path-storage", "gatekeeper-system"}
WRITE = {"create", "update", "patch", "delete", "deletecollection"}


def _platform(user: str) -> bool:
    return (user in PLATFORM
            or user.startswith("system:node:")
            or user.startswith("system:serviceaccount:kube-system:")
            or user.startswith("system:serviceaccount:kube-node-lease:")
            or user.startswith("system:serviceaccount:local-path-storage:")
            or user.startswith("system:serviceaccount:gatekeeper-system:"))


def rules(e: dict) -> list[tuple[str, str, str]]:
    """Return (severity, rule, message) for one audit event."""
    out = []
    # One request is logged at several stages; score it once.
    if e.get("stage") == "ResponseStarted":
        return out
    res = e.get("objectRef", {}) or {}
    sub = res.get("subresource")
    kind = res.get("resource")
    ns = res.get("namespace", "-")
    name = res.get("name", "-")
    verb = e.get("verb", "")
    user = (e.get("user", {}) or {}).get("username", "unknown")
    groups = (e.get("user", {}) or {}).get("groups", []) or []
    decision = (e.get("annotations", {}) or {}).get(
        "authorization.k8s.io/decision", "")

    who = f"{user} -> {verb} {kind}{'/' + sub if sub else ''} {ns}/{name}"

    if sub in ("exec", "attach") and verb == "create":
        out.append(("critical", "RUNTIME-EXEC",
                    f"shell/exec opened in a pod: {who}"))
    # The lab's assets live in dev/prod; cluster setup lives in the system
    # namespaces. Score secret/pod/RBAC activity on the app's blast radius,
    # not on kubeadm's one-time bootstrap.
    housekeeping = _platform(user) or ns in SYSTEM_NS or (
        user in BOOTSTRAP and ns in ("-", ""))
    if kind == "secrets" and verb in ("get", "list") and not housekeeping:
        out.append(("high", "SECRET-ACCESS", f"Secret read: {who}"))
    if kind == "pods" and verb == "create" and not sub and not housekeeping:
        out.append(("medium", "POD-CREATE", f"pod created: {who}"))
    if (kind in ("roles", "rolebindings", "clusterroles", "clusterrolebindings")
            and verb in WRITE and not housekeeping):
        out.append(("high", "RBAC-CHANGE", f"RBAC changed: {who}"))

    # A pipeline identity acting outside its own environment. The username is
    # github:repo:<owner>/<repo>:environment:<env>; it should only touch the
    # namespace matching <env>.
    if "github-actions" in groups and ns not in ("-", None):
        env = user.split(":environment:")[-1] if ":environment:" in user else None
        if env and ns != env and kind:
            out.append(("critical", "OIDC-CROSS-ENV",
                        f"pipeline identity for '{env}' acted in namespace "
                        f"'{ns}': {who}"))
    if decision == "forbidden":
        out.append(("info", "RBAC-DENIED", f"denied (RBAC working): {who}"))
    return out


def main() -> int:
    ap = argparse.ArgumentParser()
    default_log = Path(__file__).resolve().parents[1] / ".local/audit/audit.log"
    ap.add_argument("--audit-log", default=str(default_log))
    ap.add_argument("--json", default="")
    ap.add_argument("--quiet", action="store_true")
    a = ap.parse_args()

    log = Path(a.audit_log)
    if not log.exists():
        print(f"no audit log at {log}\n"
              "is the cluster up? (make up)  has anything happened yet?",
              file=sys.stderr)
        return 0

    findings = []
    bad_lines = 0
    for line in log.read_text(errors="replace").splitlines():
        line = line.strip()
        if not line:
            continue
        try:
            e = json.loads(line)
        except json.JSONDecodeError:
            bad_lines += 1
            continue
        for sev, rule, msg in rules(e):
            findings.append({
                "severity": sev, "rule": rule, "message": msg,
                "time": e.get("requestReceivedTimestamp", ""),
                "sourceIPs": e.get("sourceIPs", []),
            })

    findings.sort(key=lambda f: (-SEV[f["severity"]], f["time"]))
    if a.json:
        Path(a.json).parent.mkdir(parents=True, exist_ok=True)
        Path(a.json).write_text(json.dumps(findings, indent=2))

    if not a.quiet:
        if not findings:
            print(f"scanned {log} -- no suspicious activity found.")
        else:
            by = Counter(f["severity"] for f in findings)
            print(f"== {len(findings)} findings "
                  f"({', '.join(f'{by[s]} {s}' for s in SEV if by[s])}) ==\n")
            for f in findings[:50]:
                print(f"  [{f['severity'].upper():8}] {f['rule']:16} {f['message']}")
            if len(findings) > 50:
                print(f"  ... and {len(findings) - 50} more (see {a.json or '--json'})")
        if bad_lines:
            print(f"\n({bad_lines} unparsable log lines skipped)")

    return min(len(findings), 250)


if __name__ == "__main__":
    sys.exit(main())
