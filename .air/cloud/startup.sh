#!/usr/bin/env bash
# Air environment startup script for air-env-setup-test (additional repository).
# Started by the primary repository's startup script. Requires secrets API_KEY and
# DATABASE_PASSWORD (provided as environment variables by the Air env config).
# Runs on port 8000 because the primary app already uses 3000.
set -euo pipefail

if [ "${AIR_STARTUP_MODE:-}" = warmup ]; then WARMUP=1; else WARMUP=; fi
log() { echo "[startup:env-setup-test] $*"; }

REPO_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
log "repo dir: $REPO_DIR"

command -v node >/dev/null 2>&1 || { log "ERROR: node not found (the primary startup script installs it)"; exit 1; }

missing=()
[ -n "${API_KEY:-}" ] || missing+=(API_KEY)
[ -n "${DATABASE_PASSWORD:-}" ] || missing+=(DATABASE_PASSWORD)
if [ ${#missing[@]} -gt 0 ]; then
  log "ERROR: missing required secrets: ${missing[*]} - fill them in the Air environment configuration"
  exit 1
fi

APP_PORT=8000
APP_LOG=/tmp/air-env-setup-test.log
if curl -fsS "http://127.0.0.1:${APP_PORT}/" >/dev/null 2>&1; then
  log "app already answering on :${APP_PORT}"
else
  log "starting app (npm start) on :${APP_PORT}, log: $APP_LOG"
  (cd "$REPO_DIR" && PORT=$APP_PORT nohup npm start >"$APP_LOG" 2>&1 &)
fi

healthcheck() {
  log "healthcheck: waiting for GET http://127.0.0.1:${APP_PORT}/ to return 'ok'"
  local n=0
  until [ "$(curl -fsS "http://127.0.0.1:${APP_PORT}/" 2>/dev/null)" = "ok" ]; do
    n=$((n + 1))
    if grep -q "Missing required secrets" "$APP_LOG" 2>/dev/null; then
      log "ERROR: app exited:"; cat "$APP_LOG"; return 1
    fi
    if [ $((n % 10)) -eq 0 ]; then log "still waiting (attempt $n); recent log:"; tail -n 5 "$APP_LOG" || true; fi
    sleep 1
  done
  log "healthcheck passed"
}

if [ -n "$WARMUP" ]; then healthcheck; fi
log "done"
