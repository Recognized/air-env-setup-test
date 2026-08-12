#!/usr/bin/env bash
# Air environment startup script for air-env-setup-test.
#
# Runs in two modes:
#   TASK   - a real task boot. Start the app in the background and exit promptly.
#   WARMUP - the env-setup companion baking the filesystem snapshot. Same work, but
#            block on healthcheck() at the end so caches/installs land on disk.
set -euo pipefail

REPO_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
APP_PORT="${PORT:-3000}"
LOG_DIR="/tmp/air-startup"
APP_LOG="$LOG_DIR/app.log"
PID_FILE="$LOG_DIR/app.pid"

log() { printf '[startup] %s\n' "$*"; }
fail() { printf '[startup][ERROR] %s\n' "$*" >&2; exit 1; }

mkdir -p "$LOG_DIR"
cd "$REPO_DIR"

# --- mode detection -----------------------------------------------------------
# A real TASK run boots under `dind.sh air-workspace-start.sh`; the warmup run does not.
if ps -ax -o args= 2>/dev/null | grep -q 'dind.sh air-workspace-start.sh'; then
  WARMUP=
  log "mode: TASK"
else
  WARMUP=1
  log "mode: WARMUP (snapshot bake)"
fi

# --- toolchain ----------------------------------------------------------------
# Node is expected in the Air workspace image. If absent, install a userspace
# copy via nvm (sudo is password-gated, so no apt-get).
ensure_node() {
  if command -v node >/dev/null 2>&1; then
    log "node $(node --version), npm $(npm --version 2>/dev/null || echo 'n/a')"
    return 0
  fi

  log "node not found; installing Node 20 into \$HOME via nvm"
  export NVM_DIR="$HOME/.nvm"
  if [ ! -s "$NVM_DIR/nvm.sh" ]; then
    curl -fsSL https://raw.githubusercontent.com/nvm-sh/nvm/v0.40.1/install.sh | bash \
      || fail "could not download nvm (check network policy / allowed domains)"
  fi
  # shellcheck disable=SC1091
  . "$NVM_DIR/nvm.sh"
  nvm install 20 || fail "nvm install 20 failed"
  nvm alias default 20 >/dev/null 2>&1 || true
  command -v node >/dev/null 2>&1 || fail "node still unavailable after nvm install"
  log "installed node $(node --version)"
}

# --- dependencies -------------------------------------------------------------
# Cacheable: populates node_modules and the npm cache, both captured in the snapshot.
install_deps() {
  if [ -f package-lock.json ]; then
    log "installing dependencies with npm ci"
    npm ci || fail "npm ci failed"
  elif node -e 'const p=require("./package.json");process.exit((p.dependencies&&Object.keys(p.dependencies).length)||(p.devDependencies&&Object.keys(p.devDependencies).length)?0:1)' 2>/dev/null; then
    log "no lockfile; installing dependencies with npm install"
    npm install || fail "npm install failed"
  else
    log "package.json declares no dependencies; skipping install"
  fi
}

# --- app ----------------------------------------------------------------------
require_secrets() {
  local missing=()
  [ -n "${API_KEY:-}" ] || missing+=("API_KEY")
  [ -n "${DATABASE_PASSWORD:-}" ] || missing+=("DATABASE_PASSWORD")
  if [ "${#missing[@]}" -gt 0 ]; then
    fail "missing required secret(s): ${missing[*]}. Fill them in the environment configuration (they are declared there as secrets); app.js exits non-zero without them."
  fi
  log "required secrets are present (API_KEY, DATABASE_PASSWORD)"
}

start_app() {
  log "starting app on port $APP_PORT (log: $APP_LOG)"
  : > "$APP_LOG"
  PORT="$APP_PORT" nohup npm start >>"$APP_LOG" 2>&1 &
  echo $! > "$PID_FILE"
  log "app started with pid $(cat "$PID_FILE")"
}

# --- healthcheck --------------------------------------------------------------
# Asserts the environment works the way a real task needs it to: the HTTP server
# the repo ships actually answers 200 with its "ok" body. Polls until ready with
# no deadline of its own (the outer setup system applies the timeout), but exits
# non-zero immediately if the app process died — that is a definitive failure.
healthcheck() {
  local pid attempt=0 body status
  pid="$(cat "$PID_FILE" 2>/dev/null || true)"
  log "healthcheck: waiting for http://127.0.0.1:$APP_PORT/ to answer"

  while true; do
    attempt=$((attempt + 1))

    if [ -n "$pid" ] && ! kill -0 "$pid" 2>/dev/null; then
      log "healthcheck: app process $pid is no longer running; last output:"
      sed -e 's/^/    /' "$APP_LOG" >&2 || true
      fail "app exited before serving on port $APP_PORT"
    fi

    status="$(curl -fsS -o /tmp/air-startup/health-body.txt -w '%{http_code}' \
      "http://127.0.0.1:$APP_PORT/" 2>/dev/null || true)"
    body="$(cat /tmp/air-startup/health-body.txt 2>/dev/null || true)"

    if [ "$status" = "200" ] && printf '%s' "$body" | grep -q 'ok'; then
      log "healthcheck: OK - HTTP $status, body: $(printf '%s' "$body" | tr -d '\n')"
      return 0
    fi

    if [ $((attempt % 5)) -eq 0 ]; then
      log "healthcheck: still waiting (attempt $attempt, last status: ${status:-no-response})"
    fi
    sleep 2
  done
}

# --- run ----------------------------------------------------------------------
ensure_node
install_deps
require_secrets
start_app

if [ -n "${WARMUP:-}" ]; then
  healthcheck
  log "warmup complete; environment verified"
else
  log "task mode: app starting in background, not blocking on readiness"
fi

log "startup finished"
