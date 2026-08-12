#!/usr/bin/env bash
# Air environment startup script for air-env-setup-test.
#
# Runs in two modes:
#   TASK   - a real task boot: do the setup, start the app in the background, exit promptly.
#   WARMUP - the env-setup companion baking the filesystem snapshot: same setup, then block
#            in healthcheck() until the environment is proven working.
set -euo pipefail

REPO_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
PORT="${PORT:-3000}"
APP_LOG="/tmp/air-app.log"
APP_PID_FILE="/tmp/air-app.pid"

log() { echo "[startup] $*"; }

# --- mode detection ---------------------------------------------------------
_ps="$(ps -ax -o args= 2>/dev/null || true)"
if grep -q 'dind.sh air-workspace-start.sh' <<<"$_ps"; then WARMUP=; else WARMUP=1; fi
log "mode: $([ -n "${WARMUP:-}" ] && echo WARMUP || echo TASK)  repo: $REPO_DIR  port: $PORT"

# --- healthcheck ------------------------------------------------------------
# Asserts the environment works the way a real task needs it to: node/npm usable,
# the app process alive, and the HTTP server actually answering "ok" on $PORT.
# Polls until ready; no internal timeout (the outer setup system applies one).
# Fails (non-zero) as soon as the app process is known dead.
healthcheck() {
  log "healthcheck: node $(node --version), npm $(npm --version)"

  local pid=""
  [ -f "$APP_PID_FILE" ] && pid="$(cat "$APP_PID_FILE")"
  if [ -z "$pid" ]; then
    log "healthcheck FAILED: no app pid recorded at $APP_PID_FILE"
    return 1
  fi

  local attempt=0 body=""
  while :; do
    attempt=$((attempt + 1))

    if ! kill -0 "$pid" 2>/dev/null; then
      log "healthcheck FAILED: app process $pid is not running. Last output:"
      tail -n 50 "$APP_LOG" 2>/dev/null || log "(no log at $APP_LOG)"
      return 1
    fi

    if body="$(curl -fsS --max-time 5 "http://127.0.0.1:${PORT}/" 2>/dev/null)"; then
      if [ "$body" = "ok" ]; then
        log "healthcheck OK: GET http://127.0.0.1:${PORT}/ -> 'ok' (after ${attempt} attempt(s))"
        return 0
      fi
      log "healthcheck FAILED: unexpected body from port ${PORT}: '${body}' (expected 'ok')"
      return 1
    fi

    if [ $((attempt % 5)) -eq 0 ]; then
      log "healthcheck: still waiting for http://127.0.0.1:${PORT}/ (attempt ${attempt})"
    fi
    sleep 2
  done
}

# --- toolchain --------------------------------------------------------------
# node/npm ship with the Air workspace image; fail loudly (rather than silently
# later) if that ever stops being true.
if ! command -v node >/dev/null 2>&1 || ! command -v npm >/dev/null 2>&1; then
  log "ERROR: node/npm not found on PATH. This repo needs Node.js to run 'npm start'."
  exit 1
fi
log "node $(node --version), npm $(npm --version)"

cd "$REPO_DIR"

# --- required secrets -------------------------------------------------------
# app.js exits non-zero unless both are set; they come from the EnvConfig secrets.
missing=()
[ -n "${API_KEY:-}" ] || missing+=("API_KEY")
[ -n "${DATABASE_PASSWORD:-}" ] || missing+=("DATABASE_PASSWORD")
if [ "${#missing[@]}" -gt 0 ]; then
  log "ERROR: required secret(s) not set: ${missing[*]}"
  log "Fill them in the Air environment configuration (they are declared there as secrets)."
  exit 1
fi
log "required secrets present: API_KEY, DATABASE_PASSWORD"

# --- dependencies (cacheable: lands in the snapshot) ------------------------
# The app currently has no runtime dependencies, but install anyway so node_modules
# and the npm cache are primed in the snapshot the moment any dependency is added.
log "installing npm dependencies"
if [ -f package-lock.json ]; then
  npm ci --no-audit --no-fund || npm install --no-audit --no-fund
else
  npm install --no-audit --no-fund
fi
log "npm dependencies installed"

# --- start the app ----------------------------------------------------------
# Bound on 0.0.0.0 by app.js, so Orca's exposed port 3000 serves it.
if [ -f "$APP_PID_FILE" ] && kill -0 "$(cat "$APP_PID_FILE")" 2>/dev/null; then
  log "app already running (pid $(cat "$APP_PID_FILE")); leaving it alone"
else
  log "starting app: npm start (PORT=$PORT), output -> $APP_LOG"
  : >"$APP_LOG"
  PORT="$PORT" nohup npm start >>"$APP_LOG" 2>&1 &
  echo $! >"$APP_PID_FILE"
  log "app started in background (pid $(cat "$APP_PID_FILE"))"
fi

# --- readiness --------------------------------------------------------------
if [ -n "${WARMUP:-}" ]; then
  log "WARMUP run: blocking until the environment is proven healthy"
  healthcheck
  log "startup complete (verified)"
else
  log "TASK run: app starting in background; startup complete"
fi
