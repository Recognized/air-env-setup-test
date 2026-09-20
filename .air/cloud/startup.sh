#!/usr/bin/env bash
set -euo pipefail

# Air invokes startup from the checkout, including when it materializes this
# script outside the repository. Do not resolve the checkout from $0.
cd "$(git rev-parse --show-toplevel)"

: "${API_KEY:?Set API_KEY in the Air environment configuration}"
: "${DATABASE_PASSWORD:?Set DATABASE_PASSWORD in the Air environment configuration}"
export PORT="${PORT:-3000}"

echo "Checking the workspace Node.js runtime..."
node --version
npm --version
node --check app.js
# This app uses only Node's built-in HTTP module: there is nothing to install
# or build, and no dependency cache to prime.

log_dir="${HOME}/.cache/air-env-setup-test"
mkdir -p "$log_dir"
server_log="$log_dir/server.log"

healthcheck() {
  echo "Waiting for the app on port $PORT..."
  while true; do
    if ! kill -0 "$server_pid" 2>/dev/null; then
      echo "App exited before becoming ready. Server output:" >&2
      cat "$server_log" >&2
      return 1
    fi
    # A public Host header also verifies compatibility with Air's preview proxy.
    if node <<'NODE'
const http = require('http');
const request = http.get({
  hostname: '127.0.0.1',
  port: process.env.PORT,
  path: '/',
  headers: { Host: 'air-preview.example' },
}, response => {
  let body = '';
  response.setEncoding('utf8');
  response.on('data', chunk => { body += chunk; });
  response.on('error', error => { console.error(error.message); process.exit(1); });
  response.on('end', () => {
    if (response.statusCode === 200 && body === 'ok\n') {
      console.log('Healthcheck passed: HTTP 200 with expected ok response.');
      process.exit(0);
    }
    console.error('App has not returned the expected HTTP response.');
    process.exit(1);
  });
});
request.on('error', error => { console.error(error.message); process.exit(1); });
NODE
    then
      return 0
    fi
    echo "App is not ready yet; retrying..."
    sleep 2
  done
}

echo "Starting the app on port $PORT; logs: $server_log"
nohup node app.js >"$server_log" 2>&1 </dev/null &
server_pid=$!

# Processes are not snapshotted: start the app in both modes, but only block
# for readiness while baking the snapshot. Real tasks can begin immediately.
if [[ "${AIR_STARTUP_MODE:-}" == warmup ]]; then
  healthcheck
fi
