#!/usr/bin/env bash
set -euo pipefail

cd "$(dirname "$0")/../.."

if [ "${AIR_STARTUP_MODE:-}" = "warmup" ]; then
  WARMUP=1
else
  WARMUP=
fi

APP_PORT="${PORT:-3000}"
LOG_DIR="/tmp/air-startup"
APP_LOG="$LOG_DIR/air-env-setup-test-app.log"
PID_FILE="$LOG_DIR/air-env-setup-test-app.pid"
mkdir -p "$LOG_DIR"

start_app() {
  if [ -f "$PID_FILE" ]; then
    existing_pid="$(cat "$PID_FILE" 2>/dev/null || true)"
    if [ -n "$existing_pid" ] && kill -0 "$existing_pid" 2>/dev/null; then
      echo "App is already running with PID $existing_pid."
      return 0
    fi
  fi

  echo "Starting air-env-setup-test on port $APP_PORT."
  PORT="$APP_PORT" npm start >"$APP_LOG" 2>&1 &
  app_pid=$!
  echo "$app_pid" >"$PID_FILE"
  echo "App started with PID $app_pid. Logs: $APP_LOG"
}

healthcheck() {
  echo "Waiting for air-env-setup-test to answer on port $APP_PORT."
  while true; do
    if [ -f "$PID_FILE" ]; then
      app_pid="$(cat "$PID_FILE" 2>/dev/null || true)"
      if [ -n "$app_pid" ] && ! kill -0 "$app_pid" 2>/dev/null; then
        echo "App process exited before becoming ready. Recent log output:"
        tail -n 80 "$APP_LOG" 2>/dev/null || true
        return 1
      fi
    fi

    if response="$(curl -fsS "http://127.0.0.1:$APP_PORT/" 2>/dev/null)" && [ "$response" = "ok" ]; then
      echo "Healthcheck passed."
      return 0
    fi

    echo "Still waiting for the app to become ready..."
    sleep 2
  done
}

node --version
npm --version

start_app

if [ -n "${WARMUP:-}" ]; then
  healthcheck
fi
