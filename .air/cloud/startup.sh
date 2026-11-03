#!/usr/bin/env bash
# Startup script for air-env-setup-test (additional repository).
# Requires the API_KEY and DATABASE_PASSWORD secrets (provided by the environment configuration).
# Runs the app on PORT 3001 so it does not collide with the primary repository's server on 3000.
set -euo pipefail

if [ "${AIR_STARTUP_MODE:-}" = warmup ]; then WARMUP=1; else WARMUP=; fi

REPO_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
TEST_PORT="${AIR_ENV_SETUP_TEST_PORT:-3001}"
LOG_DIR="${HOME}/.air-logs"
mkdir -p "$LOG_DIR"
APP_PID=
APP_LOG="$LOG_DIR/air-env-setup-test.log"

log() { echo "[startup:env-setup-test] $*"; }

command -v node >/dev/null 2>&1 || { log "ERROR: node is not installed"; exit 1; }

missing=
for v in API_KEY DATABASE_PASSWORD; do
  [ -n "${!v:-}" ] || missing="$missing $v"
done
if [ -n "$missing" ]; then
  log "ERROR: required secrets not set:$missing (fill them in the environment configuration)"
  exit 1
fi

healthcheck() {
  log "healthcheck: waiting for http://127.0.0.1:${TEST_PORT}/ ..."
  local n=0 body
  until body="$(curl -fsS "http://127.0.0.1:${TEST_PORT}/" 2>/dev/null)" && [ "$body" = "ok" ]; do
    if [ -n "${APP_PID:-}" ] && ! kill -0 "$APP_PID" 2>/dev/null; then
      log "healthcheck: app is not running; last log lines:"
      tail -n 50 "$APP_LOG" || true
      return 1
    fi
    n=$((n + 1))
    if [ $((n % 10)) -eq 0 ]; then log "healthcheck: still waiting (${n}s)"; fi
    sleep 1
  done
  log "healthcheck: ok (GET / -> $body)"
}

cd "$REPO_DIR"
if (echo > "/dev/tcp/127.0.0.1/${TEST_PORT}") 2>/dev/null; then
  log "port ${TEST_PORT} already in use; assuming app is already running"
else
  log "starting app in background on port ${TEST_PORT} (log: $APP_LOG)"
  PORT="$TEST_PORT" nohup npm start >"$APP_LOG" 2>&1 &
  APP_PID=$!
fi

if [ -n "${WARMUP:-}" ]; then healthcheck; fi
log "done"
