#!/usr/bin/env bash
set -euo pipefail

cd "$(dirname "${BASH_SOURCE[0]}")/../.."

healthcheck() {
  echo "Waiting for the HTTP server on port ${PORT:-3000}..."
  while ! node <<'NODE'
const http = require('node:http');
const request = http.get({
  hostname: '127.0.0.1',
  port: process.env.PORT || 3000,
  path: '/',
  headers: { Host: 'air-preview.example' },
}, (response) => {
  let body = '';
  response.setEncoding('utf8');
  response.on('data', (chunk) => { body += chunk; });
  response.on('end', () => {
    process.exit(response.statusCode === 200 && body === 'ok\n' ? 0 : 1);
  });
  response.on('error', () => process.exit(1));
});
request.on('error', () => process.exit(1));
NODE
  do
    if ! kill -0 "$server_pid" 2>/dev/null; then
      echo "HTTP server exited; inspect $server_log for details." >&2
      return 1
    fi
    echo "HTTP server is not ready yet; checking again in 2 seconds..."
    sleep 2
  done
  kill -0 "$server_pid"
  echo "Healthcheck passed: HTTP 200 and expected ok response."
}

: "${API_KEY:?API_KEY must be supplied through Air environment secrets}"
: "${DATABASE_PASSWORD:?DATABASE_PASSWORD must be supplied through Air environment secrets}"
echo "Checking Node.js runtime..."
node --version
node --check app.js
# The application uses only Node.js built-ins, so there are no packages to install.
server_log="${TMPDIR:-/tmp}/air-env-setup-test-server.log"
echo "Starting HTTP server; logs: $server_log"
nohup node app.js >"$server_log" 2>&1 < /dev/null &
server_pid=$!

if [ "${AIR_STARTUP_MODE:-}" = warmup ]; then
  healthcheck
fi
