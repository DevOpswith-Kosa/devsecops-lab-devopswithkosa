#!/usr/bin/env python3
"""AIOps: diagnose a failed build.

Give it the failing logs (a file, stdin, or a GitHub Actions run id) and it
explains the root cause, names the failing step, and proposes the fix. With
--alert it opens a GitHub issue / posts to Slack.

  ai/build-doctor.py --log reports/build.log
  gh run view <id> --log-failed | ai/build-doctor.py
  ai/build-doctor.py --run-id 123456789 --alert
"""
import argparse
import subprocess
import sys
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parent))
import _client  # noqa: E402

SYSTEM = (
    "You are a senior DevSecOps engineer helping a student understand why "
    "their CI/CD pipeline failed. Be concrete and brief. Structure your "
    "answer as Markdown with exactly these sections:\n"
    "## What failed  (the one step and the key error line)\n"
    "## Why  (root cause, 1-3 sentences)\n"
    "## Fix  (numbered, copy-pasteable commands or a diff)\n"
    "## Prevent  (one pipeline change so it can't recur)\n"
    "If the logs show a security gate doing its job (a scanner found a real "
    "problem), say so plainly -- the fix is to fix the code, not the gate."
)


def get_logs(a) -> str:
    if a.run_id:
        return subprocess.run(["gh", "run", "view", a.run_id, "--log-failed"],
                              capture_output=True, text=True).stdout
    if a.log:
        return Path(a.log).read_text(errors="replace")
    return sys.stdin.read()


def main() -> int:
    ap = argparse.ArgumentParser()
    ap.add_argument("--log"); ap.add_argument("--run-id")
    ap.add_argument("--alert", action="store_true")
    ap.add_argument("--dry-run", action="store_true",
                    help="show the prompt, don't call the model")
    a = ap.parse_args()

    logs = get_logs(a).strip()
    if not logs:
        print("no logs given (use --log, --run-id, or pipe them in)", file=sys.stderr)
        return 2
    logs = logs[-24000:]  # keep the tail: that's where failures are
    prompt = f"The pipeline failed. Here are the failing logs:\n\n```\n{logs}\n```"

    if a.dry_run or not _client.have_key():
        if not a.dry_run:
            print("No Claude credential (set ANTHROPIC_API_KEY or run 'ant auth login') -- showing the prompt instead.\n", file=sys.stderr)
        print(f"# system\n{SYSTEM}\n\n# user\n{prompt}")
        return 0

    answer = _client.ask(SYSTEM, prompt)
    if a.alert:
        _client.notify("CI failed: AI diagnosis", answer, labels="ai,ci-failure")
    else:
        print(answer)
    return 0


if __name__ == "__main__":
    sys.exit(main())
