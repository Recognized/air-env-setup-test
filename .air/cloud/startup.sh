#!/usr/bin/env bash
set -euo pipefail

if [ "${AIR_STARTUP_MODE:-}" = warmup ]; then
  WARMUP=1
else
  WARMUP=
fi

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "${SCRIPT_DIR}/../.." && pwd)"
APP_LOG="/tmp/air-env-setup-test-app.log"
APP_PID_FILE="/tmp/air-env-setup-test-app.pid"
PORT="${PORT:-3000}"

cd "${REPO_ROOT}"

healthcheck() {
  echo "Waiting for air-env-setup-test to answer on port ${PORT}..."
  while true; do
    if response="$(curl -fsS "http://127.0.0.1:${PORT}/" 2>/tmp/air-env-setup-test-curl.err)" && [ "${response}" = "ok" ]; then
      echo "Healthcheck passed: app returned ok."
      return 0
    fi

    if [ -f "${APP_PID_FILE}" ]; then
      app_pid="$(cat "${APP_PID_FILE}")"
      if ! kill -0 "${app_pid}" 2>/dev/null; then
        echo "App process exited before becoming ready. Last startup log:"
        tail -n 100 "${APP_LOG}" || true
        return 1
      fi
    fi

    echo "App is not ready yet; waiting..."
    sleep 2
  done
}

echo "Checking Node.js runtime..."
node --version
npm --version

echo "Starting air-env-setup-test on 0.0.0.0:${PORT}..."
rm -f "${APP_LOG}" "${APP_PID_FILE}"
HOST=0.0.0.0 PORT="${PORT}" npm start >"${APP_LOG}" 2>&1 &
echo "$!" >"${APP_PID_FILE}"

if [ -n "${WARMUP}" ]; then
  healthcheck
fi
