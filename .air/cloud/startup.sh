#!/usr/bin/env bash
set -euo pipefail

cd "$(dirname "${BASH_SOURCE[0]}")/../.."

if [[ -z "${API_KEY:-}" || -z "${DATABASE_PASSWORD:-}" ]]; then
  echo 'Startup requires API_KEY and DATABASE_PASSWORD in the Air environment configuration.' >&2
  exit 1
fi

echo 'Checking the Node.js runtime and application syntax...'
node --version
node --check app.js
# This app uses only Node.js built-ins; there are no packages to install or build.

export PORT="${PORT:-3000}"
log_dir="$HOME/.cache/air-env-setup-test"
mkdir -p "$log_dir"
echo "Starting the HTTP server on port $PORT (log: $log_dir/server.log)..."
nohup node app.js >"$log_dir/server.log" 2>&1 < /dev/null &
server_pid=$!

healthcheck() {
  echo 'Waiting for HTTP 200 with the expected response...'
  while true; do
    if ! kill -0 "$server_pid" 2>/dev/null; then
      echo 'The HTTP server exited before becoming ready:' >&2
      cat "$log_dir/server.log" >&2
      return 1
    fi
    if node <<'NODE'
const http = require('node:http');
const request = http.get({
  hostname: '127.0.0.1',
  port: process.env.PORT,
  path: '/',
  headers: { Host: 'air-preview.example' },
}, response => {
  let body = '';
  response.setEncoding('utf8');
  response.on('data', chunk => { body += chunk; });
  response.on('end', () => {
    process.exit(response.statusCode === 200 && body === 'ok\n' ? 0 : 1);
  });
  response.on('error', () => process.exit(1));
});
request.on('error', () => process.exit(1));
NODE
    then
      echo 'Healthcheck passed: HTTP 200, body "ok".'
      return 0
    fi
    echo 'HTTP server is not ready yet; checking again in 2 seconds...'
    sleep 2
  done
}

if [[ "${AIR_STARTUP_MODE:-}" == warmup ]]; then
  healthcheck
fi
