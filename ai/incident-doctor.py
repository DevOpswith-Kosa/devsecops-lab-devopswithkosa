#!/usr/bin/env python3
"""AIOps: write the incident report for a detected attack.

Reads the detector's findings (detect/detect.py --json) and asks Claude to
explain what happened, the blast radius, the immediate containment steps, and
which Part 3 control would have prevented it. With --alert it pages you.

  detect/detect.py --json detect/findings.json
  ai/incident-doctor.py --findings detect/findings.json --alert
"""
import argparse
import json
import sys
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parent))
import _client  # noqa: E402

SYSTEM = (
    "You are the on-call responder for a Kubernetes platform. You are given "
    "findings from the API audit log. Write a short incident report in "
    "Markdown:\n"
    "## Summary  (one line: what happened, how bad)\n"
    "## Timeline  (the key events, with times)\n"
    "## Blast radius  (what the attacker could reach)\n"
    "## Contain now  (numbered kubectl/gh commands)\n"
    "## Root cause & prevention  (which specific control -- non-root, "
    "read-only FS, dropped SA token, Pod Security, Gatekeeper, OIDC, image "
    "digests/signing -- would have stopped this)\n"
    "If the findings are only INFO (e.g. RBAC correctly denying things), say "
    "there is no incident and stop."
)


def main() -> int:
    ap = argparse.ArgumentParser()
    ap.add_argument("--findings", default="detect/findings.json")
    ap.add_argument("--alert", action="store_true")
    ap.add_argument("--dry-run", action="store_true")
    a = ap.parse_args()

    p = Path(a.findings)
    if not p.exists():
        print(f"no findings at {p} -- run detect/detect.py --json {p} first.", file=sys.stderr)
        return 0
    findings = json.loads(p.read_text())
    if not findings:
        print("detector reported nothing -- no incident.")
        return 0
    prompt = ("Audit-log findings (most severe first):\n\n```json\n"
              f"{json.dumps(findings[:80], indent=1)}\n```")

    if a.dry_run or not _client.have_key():
        if not a.dry_run:
            print("No Claude credential (set ANTHROPIC_API_KEY or run 'ant auth login') -- showing the prompt instead.\n", file=sys.stderr)
        print(f"# system\n{SYSTEM}\n\n# user\n{prompt}")
        return 0

    answer = _client.ask(SYSTEM, prompt, effort="high")
    sev = {f["severity"] for f in findings}
    if a.alert and (sev & {"critical", "high"}):
        _client.notify("SECURITY INCIDENT (kubenotes)", answer, labels="ai,incident,security")
    else:
        print(answer)
    return 0


if __name__ == "__main__":
    sys.exit(main())
