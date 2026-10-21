#!/usr/bin/env bash
set -euo pipefail

cd "$(dirname "$0")/../.."

if [ "${AIR_STARTUP_MODE:-}" = "warmup" ]; then
  WARMUP=1
else
  WARMUP=
fi

APP_PORT="${PORT:-3000}"
LOG_DIR="${TMPDIR:-/tmp}/air-env-setup-test"
APP_LOG="$LOG_DIR/app.log"

mkdir -p "$LOG_DIR"

healthcheck() {
  echo "Waiting for app healthcheck on port $APP_PORT..."
  while true; do
    if response="$(curl -fsS "http://127.0.0.1:$APP_PORT/" 2>/dev/null)" && [ "$response" = "ok" ]; then
      echo "Healthcheck passed: app returned ok."
      return 0
    fi

    if [ -n "${APP_PID:-}" ] && ! kill -0 "$APP_PID" 2>/dev/null; then
      echo "App process exited before it became healthy."
      if [ -f "$APP_LOG" ]; then
        tail -100 "$APP_LOG"
      fi
      return 1
    fi

    echo "App is not ready yet; waiting..."
    sleep 2
  done
}

echo "Node version: $(node --version)"
npm --version >/dev/null

echo "Starting app on port $APP_PORT..."
PORT="$APP_PORT" npm start >"$APP_LOG" 2>&1 &
APP_PID=$!
echo "App process started with pid $APP_PID; logs: $APP_LOG"

if [ -n "$WARMUP" ]; then
  healthcheck
fi
