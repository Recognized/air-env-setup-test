#!/usr/bin/env bash
set -euo pipefail

cd "$(dirname "${BASH_SOURCE[0]}")/../.."

echo "Checking the Node.js runtime and required configuration..."
command -v node >/dev/null || { echo "Node.js is required in the workspace image." >&2; exit 1; }
node --version
for key in API_KEY DATABASE_PASSWORD; do
  if [[ -z "${!key:-}" ]]; then
    echo "Missing required secret: $key. Fill it in the Air environment configuration." >&2
    exit 1
  fi
done

# This app uses only Node.js built-ins; no dependency install or build is needed.
node --check app.js
export PORT="${PORT:-3000}"
runtime_dir="${TMPDIR:-/tmp}/air-env-setup-test"
mkdir -p "$runtime_dir"

healthcheck() {
  echo "Waiting for HTTP 200 and the expected response on port $PORT..."
  while true; do
    if ! kill -0 "$server_pid" 2>/dev/null; then
      echo "The app exited before becoming ready. Server output:" >&2
      cat "$runtime_dir/server.log" >&2
      return 1
    fi
    if node <<'NODE'
const http = require('node:http');
http.get({
  hostname: '127.0.0.1',
  port: process.env.PORT,
  // The preview proxy forwards a public hostname, not localhost.
  headers: { Host: 'air-preview.example' },
}, response => {
  let body = '';
  response.setEncoding('utf8');
  response.on('data', chunk => { body += chunk; });
  response.on('error', error => { console.error(error.message); process.exit(1); });
  response.on('end', () => {
    if (response.statusCode === 200 && body === 'ok\n') {
      console.log('Healthcheck passed: HTTP 200, body "ok".');
      process.exit(0);
    }
    console.error(`Unexpected app response: HTTP ${response.statusCode}`);
    process.exit(1);
  });
}).on('error', error => { console.error(error.message); process.exit(1); });
NODE
    then
      return 0
    fi
    echo "App is not ready yet; waiting..."
    sleep 2
  done
}

echo "Starting the app on port $PORT; output: $runtime_dir/server.log"
nohup node app.js >"$runtime_dir/server.log" 2>&1 </dev/null &
server_pid=$!

# Processes are not captured in snapshots, so start the server in both modes.
# Only snapshot warmup waits for readiness; real tasks can begin immediately.
if [[ "${AIR_STARTUP_MODE:-}" == warmup ]]; then
  healthcheck
fi
