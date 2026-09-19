#!/usr/bin/env bash
set -euo pipefail

# Air launches the materialized script with the repository as its working directory.
cd "$(git rev-parse --show-toplevel)"

if [[ -z "${API_KEY:-}" || -z "${DATABASE_PASSWORD:-}" ]]; then
  echo 'Set API_KEY and DATABASE_PASSWORD in the Air environment secrets before startup.' >&2
  exit 1
fi

if ! command -v node >/dev/null 2>&1; then
  echo 'Node.js is required; use the standard Air workspace image with Node.js installed.' >&2
  exit 1
fi
echo "Using Node.js $(node --version); this app has no package dependencies or build step."

export PORT="${PORT:-3000}"
app_log="$(mktemp /tmp/air-env-setup-test.XXXXXX.log)"
# app.js listens on all interfaces and accepts the preview proxy's Host header.
nohup node "$PWD/app.js" >"$app_log" 2>&1 </dev/null &
app_pid=$!
echo "Started app on port $PORT (PID $app_pid); log: $app_log"

healthcheck() {
  while true; do
    if ! kill -0 "$app_pid" 2>/dev/null; then
      echo 'App exited before becoming ready:' >&2
      cat "$app_log" >&2
      return 1
    fi

    if node <<'NODE'
const http = require('node:http');
http.get({
  hostname: '127.0.0.1',
  port: process.env.PORT,
  path: '/',
  headers: { Host: 'air-preview.example' },
}, (response) => {
  let body = '';
  response.setEncoding('utf8');
  response.on('data', chunk => { body += chunk; });
  response.on('error', () => process.exit(1));
  response.on('end', () => {
    process.exit(response.statusCode === 200 && body === 'ok\n' ? 0 : 1);
  });
}).on('error', () => process.exit(1));
NODE
    then
      if kill -0 "$app_pid" 2>/dev/null; then
        echo 'Healthcheck passed: HTTP 200 with the expected ok response.'
        return 0
      fi
    fi

    echo "Waiting for the app on port $PORT; log: $app_log"
    sleep 2
  done
}

# Only warmup blocks for readiness; task launches return with the server starting.
if [[ "${AIR_STARTUP_MODE:-}" == warmup ]]; then
  healthcheck
fi
