#!/usr/bin/env bash
set -euo pipefail

cd "$(git rev-parse --show-toplevel)"

_ps="$(ps -ax -o args= 2>/dev/null)"
if grep -q 'dind.sh air-workspace-start.sh' <<<"$_ps"; then
  WARMUP=
else
  WARMUP=1
fi

healthcheck() {
  echo "Waiting for the application on port ${PORT:-3000}..."
  until curl --fail --silent --show-error "http://127.0.0.1:${PORT:-3000}/" | grep -qx 'ok'; do
    if ! kill -0 "$APP_PID" 2>/dev/null; then
      echo "Application exited before becoming ready." >&2
      wait "$APP_PID"
      return 1
    fi
    echo "Application is not ready yet; retrying..."
    sleep 2
  done
  echo "Application healthcheck passed."
}

echo "Checking Node.js runtime..."
node --version
npm --version

echo "Starting application..."
npm start > /tmp/air-env-setup-test.log 2>&1 &
APP_PID=$!

if [ -n "${WARMUP:-}" ]; then
  healthcheck
fi
