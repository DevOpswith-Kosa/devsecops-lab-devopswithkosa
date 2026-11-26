#!/usr/bin/env bash
# Manage a self-hosted GitHub Actions runner on THIS machine.
#
# Why self-hosted: GitHub's cloud runners cannot reach a kind cluster that
# only exists on your laptop. A runner here can. That convenience is also the
# first thing the attack lab (Part 2) abuses -- a self-hosted runner executes
# whatever a workflow tells it to, on your machine, with your files in reach.
#
#   platform/runner/runner.sh install owner/repo
#   platform/runner/runner.sh start | stop | status | remove
set -euo pipefail
HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
DIR="$HERE/actions-runner"            # git-ignored; holds the runner + its registration
PIDFILE="$HERE/.runner.pid"
RUNNER_VERSION="2.338.2"

die(){ echo "x $*" >&2; exit 1; }
say(){ echo ">> $*"; }

arch() { case "$(uname -m)" in arm64|aarch64) echo arm64;; x86_64|amd64) echo x64;; *) die "unsupported arch";; esac; }
os()   { case "$(uname -s)" in Darwin) echo osx;; Linux) echo linux;; *) die "unsupported OS";; esac; }

cmd="${1:-help}"; shift || true

case "$cmd" in
install)
  repo="${1:-}"; [[ "$repo" =~ ^[^/]+/[^/]+$ ]] || die "usage: runner.sh install owner/repo"
  command -v gh >/dev/null || die "the GitHub CLI 'gh' is required to register the runner (brew install gh; gh auth login)"
  # The runner is a .NET app: on Linux it needs ICU, which minimal Ubuntu/WSL
  # images leave out (it then dies with "Libicu's dependencies is missing").
  if [[ "$(os)" == linux ]] && ! { ldconfig -p 2>/dev/null || /sbin/ldconfig -p 2>/dev/null; } | grep -q libicu; then
    die "the runner needs ICU. Install it, then re-run:
    Ubuntu/Debian/WSL: sudo apt-get install -y libicu-dev
    Fedora/RHEL:       sudo dnf install -y libicu"
  fi
  mkdir -p "$DIR"; cd "$DIR"
  pkg="actions-runner-$(os)-$(arch)-${RUNNER_VERSION}.tar.gz"
  if [[ ! -f config.sh ]]; then
    say "Downloading runner ${RUNNER_VERSION}"
    curl -fsSLo "$pkg" "https://github.com/actions/runner/releases/download/v${RUNNER_VERSION}/${pkg}"
    tar xzf "$pkg" && rm -f "$pkg"
  fi
  # A registration token is short-lived; gh mints it from your login.
  say "Requesting a registration token for $repo"
  token="$(gh api -X POST "repos/$repo/actions/runners/registration-token" --jq .token)"
  ./config.sh --unattended --replace \
    --url "https://github.com/$repo" --token "$token" \
    --name "$(hostname -s)-devsecops" --labels "self-hosted,devsecops" --work _work
  say "Runner registered for $repo. Start it with: make runner-start"
  ;;
start)
  [[ -x "$DIR/run.sh" ]] || die "not installed yet (make runner-install)"
  if [[ -f "$PIDFILE" ]] && kill -0 "$(cat "$PIDFILE")" 2>/dev/null; then say "already running (pid $(cat "$PIDFILE"))"; exit 0; fi
  ( cd "$DIR" && nohup ./run.sh >"$HERE/runner.log" 2>&1 & echo $! > "$PIDFILE" )
  sleep 5
  if ! kill -0 "$(cat "$PIDFILE")" 2>/dev/null; then
    rm -f "$PIDFILE"; tail -5 "$HERE/runner.log" >&2
    die "the runner exited straight away (log above, full log: platform/runner/runner.log)"
  fi
  say "Runner started (pid $(cat "$PIDFILE")). Logs: platform/runner/runner.log"
  ;;
stop)
  [[ -f "$PIDFILE" ]] && kill "$(cat "$PIDFILE")" 2>/dev/null && rm -f "$PIDFILE" && say "stopped" || say "not running"
  ;;
status)
  if [[ -f "$PIDFILE" ]] && kill -0 "$(cat "$PIDFILE")" 2>/dev/null; then say "running (pid $(cat "$PIDFILE"))"; else say "not running"; fi
  ;;
remove)
  cd "$DIR" 2>/dev/null || die "nothing to remove"
  command -v gh >/dev/null && repo_default="$(gh repo view --json nameWithOwner --jq .nameWithOwner 2>/dev/null || true)"
  [[ -f "$PIDFILE" ]] && kill "$(cat "$PIDFILE")" 2>/dev/null || true; rm -f "$PIDFILE"
  if [[ -n "${repo_default:-}" ]]; then
    token="$(gh api -X POST "repos/$repo_default/actions/runners/remove-token" --jq .token 2>/dev/null || true)"
    [[ -n "$token" ]] && ./config.sh remove --token "$token" || true
  fi
  cd "$HERE" && rm -rf "$DIR" && say "runner unregistered and deleted"
  ;;
*)
  grep '^#' "$0" | sed 's/^# \{0,1\}//'
  ;;
esac
