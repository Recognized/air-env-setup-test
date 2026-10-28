#!/usr/bin/env bash
# Air cloud startup script for air-env-setup-test.
# Ensures Node.js is available, then starts the HTTP server (app.js) on $PORT in the background.
set -euo pipefail

if [ "${AIR_STARTUP_MODE:-}" = warmup ]; then WARMUP=1; else WARMUP=; fi

REPO_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
cd "$REPO_DIR"
PORT="${PORT:-3000}"
LOG=/tmp/app.log

log() { echo "[startup] $*"; }

# --- Node.js (userspace install via nvm if not preinstalled) ---
if ! command -v node >/dev/null 2>&1; then
  export NVM_DIR="$HOME/.nvm"
  if [ ! -s "$NVM_DIR/nvm.sh" ]; then
    log "installing nvm"
    curl -fsSL https://raw.githubusercontent.com/nvm-sh/nvm/v0.40.1/install.sh | PROFILE=/dev/null bash
  fi
  # shellcheck disable=SC1091
  . "$NVM_DIR/nvm.sh"
  log "installing Node.js LTS"
  nvm install --lts
  nvm alias default 'lts/*'
  # Make nvm available to login and interactive shells.
  ENV_FILE="$HOME/.air-env.sh"
  cat > "$ENV_FILE" <<'EOS'
export NVM_DIR="$HOME/.nvm"
[ -s "$NVM_DIR/nvm.sh" ] && . "$NVM_DIR/nvm.sh"
EOS
  PROFILE_FILE=""
  for f in "$HOME/.bash_profile" "$HOME/.bash_login" "$HOME/.profile"; do
    if [ -f "$f" ]; then PROFILE_FILE="$f"; break; fi
  done
  [ -n "$PROFILE_FILE" ] || { PROFILE_FILE="$HOME/.profile"; touch "$PROFILE_FILE"; }
  for f in "$PROFILE_FILE" "$HOME/.bashrc"; do
    grep -q '# air-env-hook' "$f" 2>/dev/null || echo "[ -f \"$ENV_FILE\" ] && . \"$ENV_FILE\" # air-env-hook" >> "$f"
  done
fi
log "node $(node --version), npm $(npm --version)"

# --- Dependencies (none today, but keep this working if some are added) ---
if grep -q '"dependencies"\|"devDependencies"' package.json; then
  log "installing npm dependencies"
  npm install
fi

# --- Secrets ---
if [ -z "${API_KEY:-}" ] || [ -z "${DATABASE_PASSWORD:-}" ]; then
  log "ERROR: API_KEY and DATABASE_PASSWORD must be set (fill them as secrets in the environment configuration)"
  exit 1
fi

# --- Start the server in the background ---
if curl -fsS "http://localhost:$PORT/" >/dev/null 2>&1; then
  log "server already answering on port $PORT"
else
  log "starting app on port $PORT (log: $LOG)"
  nohup env PORT="$PORT" npm start >"$LOG" 2>&1 &
  echo $! > /tmp/app.pid
fi

healthcheck() {
  log "healthcheck: waiting for http://localhost:$PORT/ to answer 'ok'"
  local n=0 body
  while true; do
    if body="$(curl -fsS "http://localhost:$PORT/" 2>/dev/null)" && [ "$body" = "ok" ]; then
      log "healthcheck: server is up and returned 'ok'"
      return 0
    fi
    if [ -f /tmp/app.pid ] && ! kill -0 "$(cat /tmp/app.pid)" 2>/dev/null; then
      log "healthcheck: app process exited; last log lines:"
      tail -n 20 "$LOG" || true
      return 1
    fi
    n=$((n + 1))
    if [ $((n % 10)) -eq 0 ]; then log "healthcheck: still waiting ($n s)"; fi
    sleep 1
  done
}

if [ -n "${WARMUP:-}" ]; then healthcheck; fi
log "done"
