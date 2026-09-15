#!/usr/bin/env bash
set -euo pipefail
cd "$(dirname "${BASH_SOURCE[0]}")/../.."

# The workspace provides Node; this app uses only its built-in HTTP module.
echo "Checking Node runtime and application syntax..."
node --version
node --check app.js
: "${API_KEY:?Set API_KEY in the Air environment secrets}"
: "${DATABASE_PASSWORD:?Set DATABASE_PASSWORD in the Air environment secrets}"
export PORT="${PORT:-3000}"
log_dir="${HOME}/.cache/air-env-setup-test"
mkdir -p "$log_dir"
echo "Starting HTTP server on port $PORT (log: $log_dir/server.log)..."
nohup node app.js > "$log_dir/server.log" 2>&1 &
server_pid=$!

healthcheck() {
  echo "Waiting for HTTP 200 and the expected response..."
  while true; do
    if ! kill -0 "$server_pid" 2>/dev/null; then
      echo "HTTP server exited before readiness. Server output:"
      cat "$log_dir/server.log"
      return 1
    fi
    if node <<'NODE'
const http = require('http');
const req = http.get({hostname: '127.0.0.1', port: process.env.PORT,
  headers: {Host: 'air-preview.example'}}, res => {
  let body = '';
  res.on('data', chunk => body += chunk);
  res.on('end', () => process.exit(res.statusCode === 200 && body === 'ok\n' ? 0 : 1));
});
req.on('error', () => process.exit(1));
NODE
    then
      echo "Healthcheck passed: HTTP 200, body ok, with a preview Host header."
      return 0
    fi
    echo "HTTP server is not ready yet; waiting..."
    sleep 2
  done
}

# Processes must be restarted after snapshot restore. Only warmup waits for readiness.
if [[ "${AIR_STARTUP_MODE:-}" == warmup ]]; then
  healthcheck
fi
