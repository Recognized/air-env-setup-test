#!/usr/bin/env bash
set -euo pipefail

cd "$(dirname "${BASH_SOURCE[0]}")/../.."

echo "Checking Node.js and required configuration..."
node --version
npm --version
: "${API_KEY:?Set API_KEY in the Air environment secrets}"
: "${DATABASE_PASSWORD:?Set DATABASE_PASSWORD in the Air environment secrets}"

# This app uses only Node.js built-ins: there are no dependencies to install.
export PORT="${PORT:-3000}"
runtime_dir="${HOME}/.cache/air-env-setup-test"
mkdir -p "$runtime_dir"

healthcheck() {
  echo "Waiting for the app on port ${PORT}..."
  until node - <<'NODE'
const http = require('node:http');
const request = http.get({
  hostname: '127.0.0.1',
  port: process.env.PORT,
  headers: { Host: 'air-preview.example' },
}, response => {
  let body = '';
  response.setEncoding('utf8');
  response.on('data', chunk => { body += chunk; });
  response.on('end', () => {
    process.exit(response.statusCode === 200 && body === 'ok\n' ? 0 : 1);
  });
});
request.on('error', () => process.exit(1));
NODE
  do
    if ! kill -0 "$server_pid" 2>/dev/null; then
      echo "App exited before becoming ready. Server log:"
      cat "$runtime_dir/server.log"
      return 1
    fi
    echo "App not ready yet; waiting..."
    sleep 2
  done
  echo "Healthcheck passed: HTTP 200 with expected ok response."
}

echo "Starting the HTTP server on port ${PORT}..."
nohup node app.js >"$runtime_dir/server.log" 2>&1 </dev/null &
server_pid=$!

if [ "${AIR_STARTUP_MODE:-}" = warmup ]; then
  healthcheck
fi
