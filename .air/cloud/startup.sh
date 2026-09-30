#!/bin/bash
set -euo pipefail

if [ "${AIR_STARTUP_MODE:-}" = warmup ]; then WARMUP=1; else WARMUP=; fi

REPO_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
PORT="${PORT:-3000}"
APP_LOG=/tmp/app.log

cd "$REPO_DIR"
echo "[startup] node $(node --version), npm $(npm --version), mode=${AIR_STARTUP_MODE:-unset}"

if [ -z "${API_KEY:-}" ] || [ -z "${DATABASE_PASSWORD:-}" ]; then
  echo "[startup] ERROR: API_KEY and DATABASE_PASSWORD must be set (fill them on the environment configuration page)" >&2
  exit 1
fi

echo "[startup] starting app on port $PORT (log: $APP_LOG)"
nohup npm start >"$APP_LOG" 2>&1 &
APP_PID=$!
echo "[startup] app PID $APP_PID"

healthcheck() {
  echo "[healthcheck] waiting for http://localhost:$PORT/ to answer 'ok'"
  local n=0 body
  while true; do
    if ! kill -0 "$APP_PID" 2>/dev/null; then
      echo "[healthcheck] app process exited; last log lines:" >&2
      tail -n 20 "$APP_LOG" >&2 || true
      return 1
    fi
    body="$(curl -s --max-time 5 "http://localhost:$PORT/" || true)"
    if [ "$body" = "ok" ]; then
      echo "[healthcheck] app is serving on port $PORT"
      return 0
    fi
    n=$((n + 1))
    if [ $((n % 5)) -eq 0 ]; then echo "[healthcheck] still waiting (${n}s)"; fi
    sleep 1
  done
}

if [ -n "$WARMUP" ]; then
  healthcheck
fi

echo "[startup] done"
