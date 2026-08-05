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
export PORT
STARTUP_LOG="/tmp/air-env-setup-test-server.log"

healthcheck() {
  local attempts=0
  echo "Waiting for the application to answer on port ${PORT}..."
  until node -e '
    const http = require("http");
    const port = Number(process.env.PORT || 3000);
    const request = http.get({ host: "127.0.0.1", port, path: "/" }, response => {
      let body = "";
      response.setEncoding("utf8");
      response.on("data", chunk => { body += chunk; });
      response.on("end", () => process.exit(response.statusCode === 200 && body === "ok\n" ? 0 : 1));
    });
    request.on("error", () => process.exit(1));
  '
  do
    attempts=$((attempts + 1))
    if ! kill -0 "$SERVER_PID" 2>/dev/null; then
      echo "Application exited before becoming ready. Server log:"
      sed -n '1,200p' "$STARTUP_LOG"
      return 1
    fi
    if (( attempts % 10 == 0 )); then
      echo "Still waiting for the application on port ${PORT}..."
    fi
    sleep 1
  done
  echo "Application healthcheck passed."
}

echo "Starting air-env-setup-test on port ${PORT}..."
nohup npm start >"$STARTUP_LOG" 2>&1 &
SERVER_PID=$!
echo "Application started in the background (pid ${SERVER_PID})."

if [ -n "${WARMUP:-}" ]; then
  healthcheck
fi
