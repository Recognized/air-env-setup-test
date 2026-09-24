#!/usr/bin/env bash
set -euo pipefail

cd "$(dirname "$0")/../.."

if [ "${AIR_STARTUP_MODE:-}" = "warmup" ]; then
  WARMUP=1
else
  WARMUP=
fi

export PORT="${PORT:-3000}"

healthcheck() {
  echo "Waiting for air-env-setup-test on port ${PORT}..."
  while true; do
    if response="$(curl -fsS "http://127.0.0.1:${PORT}/" 2>/tmp/air-env-setup-test-healthcheck.err)" &&
      [ "$response" = "ok" ]; then
      echo "Healthcheck passed."
      return 0
    fi

    if ! kill -0 "$SERVER_PID" 2>/dev/null; then
      echo "Server exited before becoming healthy."
      wait "$SERVER_PID"
    fi

    echo "Still waiting for server readiness..."
    sleep 2
  done
}

echo "Checking Node.js runtime..."
node --version
npm --version

if [ -f package-lock.json ]; then
  echo "Installing npm dependencies..."
  npm ci
elif [ -f package.json ]; then
  echo "No package-lock.json found; skipping dependency install for this dependency-free app."
fi

if [ -z "${API_KEY:-}" ] || [ -z "${DATABASE_PASSWORD:-}" ]; then
  echo "Missing required secrets: API_KEY and DATABASE_PASSWORD must both be set."
  exit 1
fi

echo "Starting air-env-setup-test server on port ${PORT}..."
npm start &
SERVER_PID=$!

if [ -n "${WARMUP:-}" ]; then
  healthcheck
fi
