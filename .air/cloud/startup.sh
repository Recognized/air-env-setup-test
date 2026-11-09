#!/usr/bin/env bash
# Air environment startup script for air-env-setup-test.
# Runs in two modes (AIR_STARTUP_MODE): "warmup" (snapshot bake / verification) and "task".
set -euo pipefail

if [ "${AIR_STARTUP_MODE:-}" = warmup ]; then WARMUP=1; else WARMUP=; fi

REPO_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
cd "$REPO_DIR"
PORT="${PORT:-3000}"
LOG=/tmp/app.log

log() { echo "[startup] $*"; }

# --- Toolchain: Node.js ------------------------------------------------------
if ! command -v node >/dev/null 2>&1; then
  log "node not found; installing nodejs/npm via apt"
  SUDO=; [ "$(id -u)" -ne 0 ] && SUDO="sudo -n"
  $SUDO apt-get update -y
  $SUDO apt-get install -y nodejs npm
fi
log "node $(node -v), npm $(npm -v)"

# --- Dependencies ------------------------------------------------------------
# package.json has no dependencies today; keep this so adding some just works.
if [ -f package-lock.json ]; then
  log "npm ci"; npm ci --no-audit --no-fund
else
  log "npm install"; npm install --no-audit --no-fund --no-package-lock
fi

# --- Secrets check -----------------------------------------------------------
missing=()
[ -n "${API_KEY:-}" ] || missing+=(API_KEY)
[ -n "${DATABASE_PASSWORD:-}" ] || missing+=(DATABASE_PASSWORD)
if [ ${#missing[@]} -gt 0 ]; then
  log "ERROR: missing required secrets: ${missing[*]} (fill them in the Air environment configuration)"
  exit 1
fi

# --- Start the app in the background ----------------------------------------
if curl -fsS "http://localhost:${PORT}/" >/dev/null 2>&1; then
  log "app already answering on port ${PORT}"
else
  log "starting app (npm start) on port ${PORT}; logs in ${LOG}"
  PORT="$PORT" nohup npm start >"$LOG" 2>&1 &
  echo $! >/tmp/app.pid
fi

healthcheck() {
  local n=0 body
  log "healthcheck: waiting for http://localhost:${PORT}/ to answer 'ok'"
  while true; do
    if body="$(curl -fsS "http://localhost:${PORT}/" 2>/dev/null)" && [ "$body" = ok ]; then
      log "healthcheck: app is up (GET / -> '$body')"
      return 0
    fi
    # Fail fast if the app process died (e.g. bad secrets) instead of waiting forever.
    if [ -f /tmp/app.pid ] && ! kill -0 "$(cat /tmp/app.pid)" 2>/dev/null; then
      log "healthcheck: app process exited; last log lines:"
      tail -n 20 "$LOG" || true
      return 1
    fi
    n=$((n + 1))
    [ $((n % 10)) -eq 0 ] && log "healthcheck: still waiting (${n}s)"
    sleep 1
  done
}

if [ -n "${WARMUP:-}" ]; then healthcheck; fi
log "done"
