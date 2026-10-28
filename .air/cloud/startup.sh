#!/usr/bin/env bash
set -euo pipefail

cd "$(dirname "$0")/../.."

if [ "${AIR_STARTUP_MODE:-}" = "warmup" ]; then
  WARMUP=1
else
  WARMUP=
fi

export HOST="${HOST:-0.0.0.0}"
export PORT="${PORT:-3000}"

LOG_DIR="${AIR_STARTUP_LOG_DIR:-/tmp/air-startup}"
APP_LOG="$LOG_DIR/app.log"
PID_FILE="$LOG_DIR/app.pid"
mkdir -p "$LOG_DIR"

start_server() {
  if [ -s "$PID_FILE" ] && kill -0 "$(cat "$PID_FILE")" 2>/dev/null; then
    echo "Node server already running on port $PORT."
    return
  fi

  echo "Starting Node server on $HOST:$PORT."
  nohup npm start >"$APP_LOG" 2>&1 &
  echo "$!" >"$PID_FILE"
}

healthcheck() {
  echo "Waiting for Node server healthcheck on port $PORT."
  while true; do
    if curl -fsS "http://127.0.0.1:$PORT/" | grep -qx "ok"; then
      echo "Healthcheck passed."
      return 0
    fi

    if [ -s "$PID_FILE" ] && ! kill -0 "$(cat "$PID_FILE")" 2>/dev/null; then
      echo "Node server exited before becoming healthy. Recent app log:"
      tail -n 80 "$APP_LOG" || true
      return 1
    fi

    echo "Node server is not ready yet; waiting."
    sleep 2
  done
}

node --version
npm --version

start_server

if [ -n "$WARMUP" ]; then
  healthcheck
fi
