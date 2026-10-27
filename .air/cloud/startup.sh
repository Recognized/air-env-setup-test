#!/usr/bin/env bash
# Air cloud startup script for air-env-setup-test.
# Ensures Node.js is available, starts the app (node app.js) in the background on $PORT,
# and in warmup mode blocks until the server answers.
set -euo pipefail

if [ "${AIR_STARTUP_MODE:-}" = warmup ]; then WARMUP=1; else WARMUP=; fi

REPO_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
cd "$REPO_DIR"

PORT="${PORT:-3000}"
APP_LOG=/tmp/air-app.log
APP_PID_FILE=/tmp/air-app.pid

log() { echo "[startup] $*"; }

# --- Node.js toolchain -------------------------------------------------------
if ! command -v node >/dev/null 2>&1; then
  log "node not found; installing nodejs via apt"
  sudo apt-get update -y
  sudo apt-get install -y nodejs npm
fi
log "node $(node --version), npm $(npm --version 2>/dev/null || echo n/a)"

# No dependencies in package.json today; install only if some are added later.
if grep -q '"dependencies"\|"devDependencies"' package.json; then
  log "installing npm dependencies"
  if [ -f package-lock.json ]; then npm ci; else npm install; fi
fi

# --- Secrets check -----------------------------------------------------------
missing=()
[ -n "${API_KEY:-}" ] || missing+=(API_KEY)
[ -n "${DATABASE_PASSWORD:-}" ] || missing+=(DATABASE_PASSWORD)
if [ ${#missing[@]} -gt 0 ]; then
  log "ERROR: required secrets not set: ${missing[*]} (fill them in the environment configuration)"
  exit 1
fi

# --- Start the app -----------------------------------------------------------
if [ -f "$APP_PID_FILE" ] && kill -0 "$(cat "$APP_PID_FILE")" 2>/dev/null; then
  log "app already running (pid $(cat "$APP_PID_FILE"))"
else
  log "starting app on port $PORT (log: $APP_LOG)"
  PORT="$PORT" nohup node app.js >"$APP_LOG" 2>&1 &
  echo $! >"$APP_PID_FILE"
fi

healthcheck() {
  local pid n=0
  pid="$(cat "$APP_PID_FILE")"
  log "healthcheck: waiting for http://localhost:$PORT/ to answer 'ok'"
  while true; do
    if ! kill -0 "$pid" 2>/dev/null; then
      log "healthcheck FAILED: app process $pid exited; log follows"
      cat "$APP_LOG" || true
      return 1
    fi
    if [ "$(curl -fsS --noproxy '*' "http://localhost:$PORT/" 2>/dev/null)" = ok ]; then
      log "healthcheck OK: app answered 'ok' on port $PORT"
      return 0
    fi
    n=$((n + 1))
    if [ $((n % 10)) -eq 0 ]; then log "healthcheck: still waiting (${n}s)"; fi
    sleep 1
  done
}

if [ -n "${WARMUP:-}" ]; then healthcheck; fi
log "done"
