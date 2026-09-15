#!/usr/bin/env bash
set -euo pipefail

cd "$(dirname "${BASH_SOURCE[0]}")/../.."

: "${API_KEY:?API_KEY must be provided through Air environment secrets}"
: "${DATABASE_PASSWORD:?DATABASE_PASSWORD must be provided through Air environment secrets}"
export PORT="${PORT:-3000}"

echo "Checking the Node.js runtime and application syntax..."
node --version
node --check app.js
# This app uses only Node built-ins: there are no dependencies or build caches to prime.

log_dir="${XDG_CACHE_HOME:-$HOME/.cache}/air-env-setup-test"
mkdir -p "$log_dir"
server_log="$log_dir/server.log"
echo "Starting the HTTP server on port $PORT; logs: $server_log"
nohup node app.js >"$server_log" 2>&1 < /dev/null &
server_pid=$!

healthcheck() {
  local attempts=0
  while true; do
    if ! kill -0 "$server_pid" 2>/dev/null; then
      echo "HTTP server exited before becoming ready." >&2
      cat "$server_log" >&2
      return 1
    fi
    if node <<'NODE'
const http = require('node:http');
const request = http.get({
  hostname: '127.0.0.1',
  port: process.env.PORT,
  path: '/',
  headers: { Host: 'air-preview.localhost' },
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
      echo "Health check passed: GET / returned HTTP 200 with body 'ok'."
      return 0
    fi
    if (( attempts % 5 == 0 )); then
      echo "Waiting for the HTTP server to return its expected response..."
    fi
    attempts=$((attempts + 1))
    sleep 2
  done
}

if [[ "${AIR_STARTUP_MODE:-}" == warmup ]]; then
  healthcheck
fi
