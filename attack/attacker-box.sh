#!/usr/bin/env bash
# A stand-in for "the attacker's server". It listens on 127.0.0.1:9000 and
# writes whatever is sent to it into attack/loot/, with a timestamp, so you
# can watch stolen data arrive during the exercises.
#
# It stays on localhost: nothing in this lab ever leaves your machine. In a
# real attack this would be a box on the internet; the mechanism is identical.
#   attack/attacker-box.sh start | stop | tail
set -euo pipefail
HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
LOOT="$HERE/loot"; PIDFILE="$HERE/.attacker.pid"; PORT=9000
mkdir -p "$LOOT"

case "${1:-help}" in
start)
  if [[ -f "$PIDFILE" ]] && kill -0 "$(cat "$PIDFILE")" 2>/dev/null; then echo "already listening on :$PORT"; exit 0; fi
  LOOT="$LOOT" PORT="$PORT" nohup python3 "$HERE/attacker-box.py" >"$HERE/attacker.log" 2>&1 &
  echo $! > "$PIDFILE"; sleep 1
  echo "attacker box listening on http://127.0.0.1:$PORT  (loot -> attack/loot/)"
  ;;
stop)
  [[ -f "$PIDFILE" ]] && kill "$(cat "$PIDFILE")" 2>/dev/null && rm -f "$PIDFILE" && echo stopped || echo "not running"
  ;;
tail) tail -f "$HERE/attacker.log" ;;
loot) ls -la "$LOOT" ;;
*) sed -n '2,12p' "$0" | sed 's/^# \{0,1\}//' ;;
esac
