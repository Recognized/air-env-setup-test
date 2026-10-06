#!/usr/bin/env bash
# Air environment startup script for air-env-setup-test.
# Ensures Node.js is available, then starts the app (npm start) on $PORT in the background.
set -euo pipefail

if [ "${AIR_STARTUP_MODE:-}" = warmup ]; then WARMUP=1; else WARMUP=; fi

REPO_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
cd "$REPO_DIR"

PORT="${PORT:-3000}"
NODE_VERSION="${NODE_VERSION:-22.11.0}"
NODE_HOME="$HOME/.local/node"
ENV_FILE="$HOME/.air-env.sh"
APP_LOG=/tmp/app.log

# --- Node.js (userspace install if not preinstalled) ---------------------------
if ! command -v node >/dev/null 2>&1 && [ ! -x "$NODE_HOME/bin/node" ]; then
  echo "[startup] Installing Node.js v$NODE_VERSION into $NODE_HOME ..."
  case "$(uname -m)" in
    x86_64) arch=x64 ;;
    aarch64|arm64) arch=arm64 ;;
    *) echo "[startup] Unsupported arch $(uname -m)" >&2; exit 1 ;;
  esac
  mkdir -p "$NODE_HOME"
  curl -fsSL "https://nodejs.org/dist/v$NODE_VERSION/node-v$NODE_VERSION-linux-$arch.tar.xz" \
    | tar -xJ -C "$NODE_HOME" --strip-components=1
  echo "[startup] Node.js installed."
fi
if [ -x "$NODE_HOME/bin/node" ]; then
  export PATH="$NODE_HOME/bin:$PATH"
  # Persist PATH for login and interactive shells.
  echo "export PATH=\"$NODE_HOME/bin:\$PATH\"" > "$ENV_FILE"
  profile="$HOME/.profile"
  for f in "$HOME/.bash_profile" "$HOME/.bash_login" "$HOME/.profile"; do
    if [ -f "$f" ]; then profile="$f"; break; fi
  done
  for f in "$profile" "$HOME/.bashrc"; do
    grep -q '# air-env-setup' "$f" 2>/dev/null || echo "[ -f \"$ENV_FILE\" ] && . \"$ENV_FILE\" # air-env-setup" >> "$f"
  done
fi
echo "[startup] node $(node -v), npm $(npm -v)"

# --- Dependencies (none today, but keep this cheap and future-proof) -----------
if [ -f package-lock.json ]; then
  npm ci
elif grep -q '"dependencies"\|"devDependencies"' package.json; then
  npm install
fi

# --- Secrets check -------------------------------------------------------------
if [ -z "${API_KEY:-}" ] || [ -z "${DATABASE_PASSWORD:-}" ]; then
  echo "[startup] ERROR: API_KEY and DATABASE_PASSWORD must be set (fill them in the Air environment configuration)." >&2
  exit 1
fi

# --- Start the app in the background -------------------------------------------
if curl -fsS "http://localhost:$PORT/" >/dev/null 2>&1; then
  echo "[startup] App already answering on port $PORT."
else
  echo "[startup] Starting app on port $PORT (log: $APP_LOG) ..."
  PORT="$PORT" nohup npm start >"$APP_LOG" 2>&1 &
  echo "$!" > /tmp/app.pid
fi

healthcheck() {
  local n=0 body
  echo "[healthcheck] Waiting for app on http://localhost:$PORT/ ..."
  while true; do
    if body="$(curl -fsS "http://localhost:$PORT/" 2>/dev/null)" && [ "$body" = "ok" ]; then
      echo "[healthcheck] App is serving 'ok' on port $PORT."
      return 0
    fi
    if [ -f /tmp/app.pid ] && ! kill -0 "$(cat /tmp/app.pid)" 2>/dev/null; then
      echo "[healthcheck] App process exited. Last log lines:" >&2
      tail -n 20 "$APP_LOG" >&2 || true
      return 1
    fi
    n=$((n + 1))
    if [ $((n % 10)) -eq 0 ]; then echo "[healthcheck] still waiting ($n s) ..."; fi
    sleep 1
  done
}

if [ -n "${WARMUP:-}" ]; then healthcheck; fi
echo "[startup] Done."
