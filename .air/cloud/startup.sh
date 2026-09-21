#!/usr/bin/env bash
set -euo pipefail

# Air runs the materialized script from the repository working directory.
cd "$(git rev-parse --show-toplevel)"

if [[ -z "${API_KEY:-}" || -z "${DATABASE_PASSWORD:-}" ]]; then
  echo 'Set API_KEY and DATABASE_PASSWORD in the Air environment secrets.' >&2
  exit 1
fi

echo "Using Node.js $(node --version) and npm $(npm --version)"
# This app uses only Node.js built-ins; there is nothing to install or build.
node --check app.js

export PORT="${PORT:-3000}"
log_dir="$HOME/.cache/air-env-setup-test"
mkdir -p "$log_dir"
app_log="$log_dir/server.log"

healthcheck() {
  echo "Waiting for the app on port $PORT..."
  while true; do
    if ! kill -0 "$server_pid" 2>/dev/null; then
      echo "The app exited before becoming ready. Server log:" >&2
      cat "$app_log" >&2
      return 1
    fi
    if node <<'NODE'
const http = require('http');
http.get({
  hostname: '127.0.0.1',
  port: process.env.PORT,
  path: '/',
  // The preview proxy forwards its hostname, so arbitrary Hosts must work.
  headers: { Host: 'air-preview.example' },
}, response => {
  let body = '';
  response.setEncoding('utf8');
  response.on('data', chunk => { body += chunk; });
  response.on('error', error => {
    console.error(error.message);
    process.exit(1);
  });
  response.on('end', () => {
    const ready = response.statusCode === 200 && body === 'ok\n';
    if (!ready) console.error('App has not returned HTTP 200 with the expected ok response.');
    process.exit(ready ? 0 : 1);
  });
}).on('error', error => {
  console.error(error.message);
  process.exit(1);
});
NODE
    then
      echo 'App ready: HTTP 200 with the expected ok response.'
      return 0
    fi
    echo 'App is not ready yet; checking again in 2 seconds.'
    sleep 2
  done
}

echo "Starting the app on port $PORT; log: $app_log"
nohup node app.js >"$app_log" 2>&1 </dev/null &
server_pid=$!

# Processes are not snapshotted: start the app in both modes, but only wait
# during warmup. The outer setup service controls the readiness timeout.
if [[ "${AIR_STARTUP_MODE:-}" == warmup ]]; then
  healthcheck
fi
