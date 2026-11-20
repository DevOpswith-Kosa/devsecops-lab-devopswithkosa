"""Shared helpers for the AI tools: one Claude call, one way to raise an alert.

Keeps the three tools (build-doctor, security-triage, incident-doctor) small
and consistent. Model and prompting follow Anthropic's current guidance:
Claude Opus 5.5 with adaptive thinking and a server-side refusal fallback.
"""
from __future__ import annotations

import json
import os
import subprocess
import sys
import urllib.request

MODEL = "claude-opus-5-5"


def have_key() -> bool:
    return bool(os.environ.get("ANTHROPIC_API_KEY") or os.environ.get("ANTHROPIC_AUTH_TOKEN"))


def ask(system: str, prompt: str, *, effort: str = "high", max_tokens: int = 8000) -> str:
    """Send one request to Claude and return the text. Streams so long
    answers don't hit the HTTP timeout. Falls back gracefully if the beta
    fallback parameter isn't accepted by the installed SDK/endpoint."""
    import anthropic

    client = anthropic.Anthropic()
    kwargs = dict(
        model=MODEL,
        max_tokens=max_tokens,
        system=system,
        thinking={"type": "adaptive"},
        output_config={"effort": effort},
        messages=[{"role": "user", "content": prompt}],
    )

    def _collect(stream_ctx) -> str:
        with stream_ctx as stream:
            msg = stream.get_final_message()
        if getattr(msg, "stop_reason", None) == "refusal":
            return "[the model declined to answer this request]"
        return "".join(b.text for b in msg.content if b.type == "text").strip()

    try:
        # Opus 5.5: opt into a server-side fallback on a safety refusal.
        return _collect(client.beta.messages.stream(
            betas=["server-side-fallback-2026-07-01"],
            fallbacks="default", **kwargs))
    except (TypeError, anthropic.BadRequestError):
        return _collect(client.messages.stream(**kwargs))


def notify(title: str, body: str, *, labels: str = "ai,incident") -> None:
    """Raise an alert on the channels that are configured, else print.
      - GitHub issue, if `gh` is authenticated (ALERT_GH=off to disable)
      - Slack, if SLACK_WEBHOOK_URL is set
    Always prints to stdout so nothing is lost."""
    print(f"\n{'=' * 70}\n{title}\n{'=' * 70}\n{body}\n")

    hook = os.environ.get("SLACK_WEBHOOK_URL")
    if hook:
        try:
            payload = json.dumps({"text": f"*{title}*\n{body[:3500]}"}).encode()
            req = urllib.request.Request(hook, data=payload,
                                         headers={"Content-Type": "application/json"})
            urllib.request.urlopen(req, timeout=10).read()
            print("(posted to Slack)")
        except Exception as e:  # noqa: BLE001 - alerting must never crash the tool
            print(f"(Slack alert failed: {e})", file=sys.stderr)

    if os.environ.get("ALERT_GH", "on") != "off":
        try:
            subprocess.run(
                ["gh", "issue", "create", "--title", title,
                 "--label", labels, "--body", body],
                check=True, capture_output=True, text=True, timeout=30)
            print("(opened a GitHub issue)")
        except Exception:  # noqa: BLE001 - gh may be absent or unauthenticated
            pass
