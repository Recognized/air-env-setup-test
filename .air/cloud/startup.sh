#!/bin/bash
set -euo pipefail

if [ "${AIR_STARTUP_MODE:-}" = warmup ]; then WARMUP=1; else WARMUP=; fi

cd "$(dirname "$0")/../.."
PORT="${PORT:-3000}"
LOG=/tmp/app.log

echo "[startup] node $(node --version), npm $(npm --version)"
echo "[startup] installing dependencies..."
npm install --no-audit --no-fund
echo "[startup] dependencies installed"

if [ -z "${API_KEY:-}" ] || [ -z "${DATABASE_PASSWORD:-}" ]; then
  echo "[startup] ERROR: API_KEY and DATABASE_PASSWORD must be set (fill them on the environment configuration page)" >&2
  exit 1
fi

echo "[startup] starting app on port $PORT (log: $LOG)"
PORT="$PORT" nohup npm start >"$LOG" 2>&1 &
APP_PID=$!

healthcheck() {
  echo "[healthcheck] waiting for http://localhost:$PORT/ to answer 'ok'..."
  local n=0
  while true; do
    if ! kill -0 "$APP_PID" 2>/dev/null; then
      echo "[healthcheck] app process exited; last log lines:" >&2
      tail -20 "$LOG" >&2
      return 1
    fi
    if [ "$(curl -fsS "http://localhost:$PORT/" 2>/dev/null || true)" = "ok" ]; then
      echo "[healthcheck] app is serving on port $PORT"
      return 0
    fi
    n=$((n + 1))
    [ $((n % 10)) -eq 0 ] && echo "[healthcheck] still waiting (${n}s)..."
    sleep 1
  done
}

if [ -n "$WARMUP" ]; then healthcheck; fi
echo "[startup] done"
