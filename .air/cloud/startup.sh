#!/usr/bin/env bash
# Air environment startup script for air-env-setup-test.
# Starts the tiny HTTP server (app.js) in the background; in warmup mode blocks until it answers.
set -euo pipefail

if [ "${AIR_STARTUP_MODE:-}" = warmup ]; then WARMUP=1; else WARMUP=; fi

REPO_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
cd "$REPO_DIR"

PORT="${PORT:-3000}"
APP_LOG=/tmp/app.log
APP_PID_FILE=/tmp/app.pid

echo "[startup] mode=${AIR_STARTUP_MODE:-unset} repo=$REPO_DIR"

if ! command -v node >/dev/null 2>&1; then
  echo "[startup] ERROR: node not found on PATH" >&2
  exit 1
fi
echo "[startup] node $(node -v), npm $(npm -v)"

# app.js refuses to start without these; report which are missing (never their values).
missing=()
for v in API_KEY DATABASE_PASSWORD; do
  [ -n "${!v:-}" ] || missing+=("$v")
done
if [ ${#missing[@]} -gt 0 ]; then
  echo "[startup] ERROR: missing required secrets: ${missing[*]} (fill them in the Air environment configuration)" >&2
  exit 1
fi

# No dependencies today, but install if any are added later.
if [ -f package-lock.json ]; then
  echo "[startup] npm ci"; npm ci
elif grep -q '"dependencies"\|"devDependencies"' package.json; then
  echo "[startup] npm install"; npm install
fi

healthcheck() {
  echo "[healthcheck] waiting for http://localhost:$PORT/ to answer 'ok'"
  local n=0
  while true; do
    if body=$(curl -fsS "http://localhost:$PORT/" 2>/dev/null) && [ "$body" = "ok" ]; then
      echo "[healthcheck] server is up on port $PORT"
      return 0
    fi
    if [ -f "$APP_PID_FILE" ] && ! kill -0 "$(cat "$APP_PID_FILE")" 2>/dev/null; then
      echo "[healthcheck] ERROR: app process exited; last log lines:" >&2
      tail -n 20 "$APP_LOG" >&2 || true
      return 1
    fi
    n=$((n + 1))
    if [ $((n % 10)) -eq 0 ]; then echo "[healthcheck] still waiting (${n}s)"; fi
    sleep 1
  done
}

if curl -fsS "http://localhost:$PORT/" >/dev/null 2>&1; then
  echo "[startup] something already answers on port $PORT; not starting another server"
  rm -f "$APP_PID_FILE"
else
  echo "[startup] starting app on port $PORT (log: $APP_LOG)"
  PORT="$PORT" nohup node app.js >"$APP_LOG" 2>&1 &
  echo $! >"$APP_PID_FILE"
fi

if [ -n "${WARMUP:-}" ]; then healthcheck; fi
echo "[startup] done"
