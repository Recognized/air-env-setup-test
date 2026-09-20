#!/usr/bin/env bash
set -euo pipefail

cd "$(dirname "${BASH_SOURCE[0]}")/../.."

healthcheck() {
  echo 'Waiting for the app to return HTTP 200 with ok...'
  until node <<'JS'
const http = require('node:http');
const request = http.get({
  hostname: '127.0.0.1',
  port: process.env.PORT || 3000,
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
request.setTimeout(2000, () => request.destroy());
request.on('error', () => process.exit(1));
JS
  do
    if ! kill -0 "$server_pid" 2>/dev/null; then
      echo "App exited before readiness. See $log_file" >&2
      cat "$log_file" >&2
      return 1
    fi
    echo 'App is not ready yet; checking again in 2 seconds...'
    sleep 2
  done
  echo 'Healthcheck passed: HTTP 200, expected ok response.'
}

command -v node >/dev/null || { echo 'Node.js is required in the workspace image.' >&2; exit 1; }
: "${API_KEY:?Set API_KEY in Air personal secrets.}"
: "${DATABASE_PASSWORD:?Set DATABASE_PASSWORD in Air personal secrets.}"
echo "Using Node.js $(node --version); this app has no package dependencies to install."
node --check app.js

log_dir="$HOME/.cache/air-env-setup-test"
mkdir -p "$log_dir"
log_file="$log_dir/server.log"
echo "Starting the app on port ${PORT:-3000}; log: $log_file"
nohup node app.js >"$log_file" 2>&1 < /dev/null &
server_pid=$!

if [ "${AIR_STARTUP_MODE:-}" = warmup ]; then
  healthcheck
fi
