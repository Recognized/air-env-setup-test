#!/usr/bin/env bash
set -euo pipefail

cd "$(git rev-parse --show-toplevel)"

_ps="$(ps -ax -o args= 2>/dev/null)"
if grep -q 'dind.sh air-workspace-start.sh' <<<"$_ps"; then
  WARMUP=
else
  WARMUP=1
fi

PORT="${PORT:-3000}"
LOG_DIR="${AIR_ARTIFACTS_DIR:-/tmp/air-env-setup-test}"
mkdir -p "$LOG_DIR"
SERVER_LOG="$LOG_DIR/server.log"

healthcheck() {
  echo "Waiting for the app at http://127.0.0.1:${PORT}/"
  while ! curl --fail --silent --show-error "http://127.0.0.1:${PORT}/" | grep -qx 'ok'; do
    if ! kill -0 "$SERVER_PID" 2>/dev/null; then
      echo "The app exited before becoming ready. Server log follows:" >&2
      tail -n 100 "$SERVER_LOG" >&2 || true
      return 1
    fi
    echo "App is still starting..."
    sleep 1
  done
  echo "App healthcheck passed."
}

echo "Node version: $(node --version)"
echo "Starting the development server on port ${PORT}..."
PORT="$PORT" nohup npm start >"$SERVER_LOG" 2>&1 &
SERVER_PID=$!

if [ -n "${WARMUP:-}" ]; then
  healthcheck
fi
