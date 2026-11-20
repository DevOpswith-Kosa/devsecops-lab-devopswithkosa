#!/usr/bin/env python3
"""AIOps: turn scanner reports into a prioritised fix list.

Reads the SARIF/JSON reports in reports/ (Trivy, Semgrep, Gitleaks) and asks
Claude to rank what matters, with the one action that clears each item.

  make scan            # produce the reports first
  ai/security-triage.py
  ai/security-triage.py --reports reports --top 10 --alert
"""
import argparse
import json
import sys
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parent))
import _client  # noqa: E402

SYSTEM = (
    "You are an application security engineer triaging scanner output for a "
    "developer. Cut the noise. Output Markdown:\n"
    "## Top risks  (a table: # | severity | where file:line | what | fix in one line)\n"
    "## Do first  (the 3 that matter most and why)\n"
    "## Likely false positives / accepted  (with a reason)\n"
    "Judge by real exploitability in a small Flask app on Kubernetes, not by "
    "raw scanner severity. Be specific about files."
)


def load_sarif(p: Path) -> list[dict]:
    out = []
    try:
        d = json.loads(p.read_text())
    except Exception:  # noqa: BLE001
        return out
    for run in d.get("runs", []):
        tool = run.get("tool", {}).get("driver", {}).get("name", p.stem)
        for r in run.get("results", []):
            loc = (r.get("locations") or [{}])[0].get("physicalLocation", {})
            out.append({
                "tool": tool,
                "level": r.get("level", "warning"),
                "rule": r.get("ruleId", ""),
                "msg": (r.get("message", {}) or {}).get("text", "")[:300],
                "file": loc.get("artifactLocation", {}).get("uri", ""),
                "line": loc.get("region", {}).get("startLine", ""),
            })
    return out


def main() -> int:
    ap = argparse.ArgumentParser()
    ap.add_argument("--reports", default="reports")
    ap.add_argument("--top", type=int, default=12)
    ap.add_argument("--alert", action="store_true")
    ap.add_argument("--dry-run", action="store_true")
    a = ap.parse_args()

    rd = Path(a.reports)
    findings = []
    for p in sorted(rd.glob("*.sarif")):
        findings += load_sarif(p)
    if not findings:
        print(f"no SARIF reports in {rd}/ -- run `make scan` first.", file=sys.stderr)
        return 0
    prompt = (f"{len(findings)} findings from the scanners. Prioritise the top "
              f"{a.top}.\n\n```json\n{json.dumps(findings, indent=1)[:22000]}\n```")

    if a.dry_run or not _client.have_key():
        if not a.dry_run:
            print("No Claude credential (set ANTHROPIC_API_KEY or run 'ant auth login') -- showing the prompt instead.\n", file=sys.stderr)
        print(f"# system\n{SYSTEM}\n\n# user\n{prompt}")
        return 0

    answer = _client.ask(SYSTEM, prompt)
    if a.alert:
        _client.notify("Security triage", answer, labels="ai,security")
    else:
        print(answer)
    return 0


if __name__ == "__main__":
    sys.exit(main())
