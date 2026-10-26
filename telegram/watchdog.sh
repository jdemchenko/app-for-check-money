#!/usr/bin/env bash
# Keep the Telegram bridge alive across agent turns when possible.
# Parent can ping by running: bash telegram/watchdog.sh --once
# Note: on Cloud Agent VMs the process may still die if the workload
# cgroup is torn down; then re-run ./telegram/run-bridge.sh.
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
STORE="${CURSOR_PROJECT_STORE:-/cursor/stores/bc-01a177a1-f21e-77ce-af41-f6f83ca48221}"
PIDFILE="$STORE/internal/telegram-bridge.pid"
LOG="$STORE/internal/watchdog.log"
ONCE=0
[[ "${1:-}" == "--once" ]] && ONCE=1

mkdir -p "$STORE/internal"
log() { echo "$(date -u +%Y-%m-%dT%H:%M:%SZ) $*" | tee -a "$LOG"; }

ensure() {
  local pid=""
  if [[ -f "$PIDFILE" ]]; then
    pid="$(cat "$PIDFILE" 2>/dev/null || true)"
  fi
  if [[ -n "${pid:-}" ]] && kill -0 "$pid" 2>/dev/null; then
    # Confirm it is our bridge
    if tr '\0' ' ' <"/proc/$pid/cmdline" 2>/dev/null | grep -q "telegram/bridge.mjs"; then
      log "ok pid=$pid"
      return 0
    fi
  fi
  log "restarting bridge"
  bash "$ROOT/telegram/run-bridge.sh" | tee -a "$LOG"
}

if [[ "$ONCE" -eq 1 ]]; then
  ensure
  exit 0
fi

log "watchdog loop start"
while true; do
  ensure || true
  sleep 20
done
