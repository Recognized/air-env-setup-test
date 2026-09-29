#!/usr/bin/env bash
# Air cloud startup script for air-env-setup-test.
# Starts the tiny Node HTTP server (app.js) on $PORT (default 3000).
set -euo pipefail

if [ "${AIR_STARTUP_MODE:-}" = warmup ]; then WARMUP=1; else WARMUP=; fi

REPO_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
cd "$REPO_DIR"
PORT="${PORT:-3000}"
LOG=/tmp/app.log

echo "[startup] node $(node -v), npm $(npm -v)"

# Fail early with a clear message when secrets are missing (never print values).
for v in API_KEY DATABASE_PASSWORD; do
  if [ -z "${!v:-}" ]; then
    echo "[startup] ERROR: required secret $v is not set; fill it in the environment configuration." >&2
    exit 1
  fi
done

# No dependencies today, but keep install so future deps get cached in the snapshot.
echo "[startup] installing npm dependencies"
npm install --no-audit --no-fund
echo "[startup] npm install done"

healthcheck() {
  local n=0
  echo "[healthcheck] waiting for app on port $PORT"
  until body=$(curl -fsS "http://localhost:$PORT/" 2>/dev/null) && [ "$body" = ok ]; do
    if ! kill -0 "$APP_PID" 2>/dev/null; then
      echo "[healthcheck] ERROR: app process exited; last log lines:" >&2
      tail -n 20 "$LOG" >&2 || true
      return 1
    fi
    n=$((n + 1))
    [ $((n % 10)) -eq 0 ] && echo "[healthcheck] still waiting ($n polls)"
    sleep 1
  done
  echo "[healthcheck] app answered 'ok' on port $PORT"
}

echo "[startup] starting app in background (log: $LOG)"
PORT="$PORT" nohup npm start >"$LOG" 2>&1 &
APP_PID=$!

if [ -n "${WARMUP:-}" ]; then healthcheck; fi
echo "[startup] done"
