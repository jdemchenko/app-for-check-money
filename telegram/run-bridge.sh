#!/usr/bin/env bash
# Durable launcher for the Telegram long-poll bridge.
# Survives agent turn end when started under tmux or nohup.
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
STORE="${CURSOR_PROJECT_STORE:-/cursor/stores/bc-01a177a1-f21e-77ce-af41-f6f83ca48221}"
export TELEGRAM_ENV_FILE="${TELEGRAM_ENV_FILE:-$STORE/internal/secrets/telegram.env}"
export TELEGRAM_INBOX_FILE="${TELEGRAM_INBOX_FILE:-$STORE/internal/telegram-inbox.md}"
export SOLANA_PUBKEY_FILE="${SOLANA_PUBKEY_FILE:-$STORE/internal/secrets/solana-usdc-deposit.pubkey}"
LOG_DIR="${BRIDGE_LOG_DIR:-$STORE/internal}"
mkdir -p "$LOG_DIR"
LOG="$LOG_DIR/telegram-bridge.log"
PIDFILE="$LOG_DIR/telegram-bridge.pid"

cd "$ROOT"
# Replace any previous bridge
if [[ -f "$PIDFILE" ]]; then
  old="$(cat "$PIDFILE" 2>/dev/null || true)"
  if [[ -n "${old:-}" ]] && kill -0 "$old" 2>/dev/null; then
    kill "$old" 2>/dev/null || true
    sleep 1
  fi
fi
pkill -f "node telegram/bridge.mjs" 2>/dev/null || true
sleep 0.5

nohup node telegram/bridge.mjs >>"$LOG" 2>&1 &
echo $! >"$PIDFILE"
echo "started pid=$(cat "$PIDFILE") log=$LOG"
