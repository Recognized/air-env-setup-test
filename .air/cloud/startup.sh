#!/usr/bin/env bash
# Air environment startup script for air-env-setup-test.
# Ensures Node.js is available and starts the app (npm start) in the background on PORT (default 3000).
set -euo pipefail

if [ "${AIR_STARTUP_MODE:-}" = warmup ]; then WARMUP=1; else WARMUP=; fi

REPO_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
cd "$REPO_DIR"
PORT="${PORT:-3000}"
APP_LOG=/tmp/app.log

# --- Node.js toolchain ---
if ! command -v node >/dev/null 2>&1; then
  echo "[startup] node not found; installing nodejs via apt..."
  sudo apt-get update -y
  sudo apt-get install -y nodejs npm
fi
echo "[startup] node $(node --version), npm $(npm --version)"

# --- Dependencies (none today, but keep this cheap step for future deps) ---
if [ -f package-lock.json ]; then
  npm ci
fi

# --- Secrets check (values are never printed) ---
missing=
for v in API_KEY DATABASE_PASSWORD; do
  if [ -z "${!v:-}" ]; then missing="$missing $v"; fi
done
if [ -n "$missing" ]; then
  echo "[startup] ERROR: required secrets not set:$missing (fill them in the environment configuration)" >&2
  exit 1
fi

# --- Start app in the background ---
if curl -fsS "http://localhost:${PORT}/" >/dev/null 2>&1; then
  echo "[startup] app already answering on port ${PORT}"
else
  echo "[startup] starting app (npm start) on port ${PORT}; log: ${APP_LOG}"
  PORT="$PORT" nohup npm start >"$APP_LOG" 2>&1 &
  echo $! >/tmp/app.pid
fi

healthcheck() {
  echo "[healthcheck] waiting for app on http://localhost:${PORT}/ ..."
  local n=0
  while true; do
    if body="$(curl -fsS "http://localhost:${PORT}/" 2>/dev/null)" && [ "$body" = "ok" ]; then
      echo "[healthcheck] app answered 'ok' on port ${PORT}"
      return 0
    fi
    if [ -f /tmp/app.pid ] && ! kill -0 "$(cat /tmp/app.pid)" 2>/dev/null; then
      echo "[healthcheck] ERROR: app process exited; last log lines:" >&2
      tail -n 20 "$APP_LOG" >&2 || true
      return 1
    fi
    n=$((n + 1))
    if [ $((n % 10)) -eq 0 ]; then echo "[healthcheck] still waiting (${n}s)..."; fi
    sleep 1
  done
}

if [ -n "${WARMUP:-}" ]; then healthcheck; fi
echo "[startup] done"
