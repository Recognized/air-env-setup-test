#!/usr/bin/env bash
set -euo pipefail

cd "$(git rev-parse --show-toplevel)"

_ps="$(ps -ax -o args= 2>/dev/null)"
if grep -q 'dind.sh air-workspace-start.sh' <<<"$_ps"; then
  WARMUP=
else
  WARMUP=1
fi

# Validate the runtime and warm npm's local metadata/cache. This project has no
# third-party dependencies, but npm install also verifies the manifest is usable.
node --check app.js
npm install --ignore-scripts --no-audit --no-fund

PORT="${PORT:-3000}"
export PORT
STARTUP_LOG="${TMPDIR:-/tmp}/air-env-setup-test-server.log"
nohup npm start >"$STARTUP_LOG" 2>&1 &
SERVER_PID=$!

healthcheck() {
  while true; do
    if ! kill -0 "$SERVER_PID" 2>/dev/null; then
      wait "$SERVER_PID" || true
      cat "$STARTUP_LOG" >&2
      return 1
    fi

    if node -e '
      const port = Number(process.env.PORT || 3000);
      const request = require("http").get({ host: "127.0.0.1", port }, response => {
        let body = "";
        response.setEncoding("utf8");
        response.on("data", chunk => { body += chunk; });
        response.on("end", () => process.exit(response.statusCode === 200 && body === "ok\n" ? 0 : 1));
      });
      request.on("error", () => process.exit(1));
    '; then
      return 0
    fi

    sleep 1
  done
}

if [ -n "${WARMUP:-}" ]; then
  healthcheck
fi
