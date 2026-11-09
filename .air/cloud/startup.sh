#!/usr/bin/env bash
# Air environment startup script for air-env-setup-test.
# Ensures Node.js is available, starts the HTTP server (app.js) in the background,
# and in WARMUP mode blocks on a healthcheck until the server answers.
set -euo pipefail

if [ "${AIR_STARTUP_MODE:-}" = warmup ]; then WARMUP=1; else WARMUP=; fi

REPO_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
cd "$REPO_DIR"
PORT="${PORT:-3000}"
APP_LOG=/tmp/app.log

log() { echo "[startup] $*"; }

# --- Node.js toolchain ---------------------------------------------------------
if ! command -v node >/dev/null 2>&1; then
  log "node not found; installing Node.js via apt"
  if sudo -n true 2>/dev/null; then SUDO="sudo -n"; else SUDO="sudo"; fi
  $SUDO apt-get update -y
  $SUDO apt-get install -y nodejs npm
fi
log "node $(node --version), npm $(npm --version 2>/dev/null || echo n/a)"

# --- Dependencies (none today; keeps working if some are added) ---------------
if [ -f package-lock.json ]; then
  log "installing dependencies (npm ci)"; npm ci
elif grep -q '"dependencies"' package.json 2>/dev/null; then
  log "installing dependencies (npm install)"; npm install
fi

# --- Secrets check --------------------------------------------------------------
missing=
for v in API_KEY DATABASE_PASSWORD; do
  [ -n "${!v:-}" ] || missing="$missing $v"
done
if [ -n "$missing" ]; then
  log "ERROR: required secrets not set:$missing (fill them in the environment configuration)"
  exit 1
fi

# --- Start the server in the background ----------------------------------------
if curl -fsS "http://localhost:${PORT}/" >/dev/null 2>&1; then
  log "server already answering on port ${PORT}"
else
  log "starting server on port ${PORT} (log: ${APP_LOG})"
  PORT="$PORT" nohup npm start >"$APP_LOG" 2>&1 &
  echo $! >/tmp/app.pid
fi

healthcheck() {
  log "healthcheck: waiting for http://localhost:${PORT}/ to return 'ok'"
  local n=0 body
  while true; do
    if body="$(curl -fsS "http://localhost:${PORT}/" 2>/dev/null)" && [ "$body" = "ok" ]; then
      log "healthcheck: server is up (response: ${body})"
      return 0
    fi
    if [ -f /tmp/app.pid ] && ! kill -0 "$(cat /tmp/app.pid)" 2>/dev/null; then
      log "healthcheck: server process exited; last log lines:"
      tail -n 20 "$APP_LOG" || true
      return 1
    fi
    n=$((n + 1))
    if [ $((n % 10)) -eq 0 ]; then log "healthcheck: still waiting (${n}s)"; fi
    sleep 1
  done
}

if [ -n "${WARMUP:-}" ]; then healthcheck; fi
log "done"
