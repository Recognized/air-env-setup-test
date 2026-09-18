#!/usr/bin/env bash
set -euo pipefail

cd "$(git rev-parse --show-toplevel)"

echo "Checking the Node.js runtime and required configuration..."
node --version
npm --version
: "${API_KEY:?API_KEY must be supplied through the environment configuration}"
: "${DATABASE_PASSWORD:?DATABASE_PASSWORD must be supplied through the environment configuration}"
export PORT="${PORT:-3000}"

# The app uses only built-in Node modules; there are no packages to install or build.
node --check app.js
log_dir="${HOME}/.cache/air-env-setup-test"
mkdir -p "$log_dir"
echo "Starting the HTTP server on port $PORT (log: $log_dir/server.log)..."
nohup node app.js >"$log_dir/server.log" 2>&1 </dev/null &
server_pid=$!

healthcheck() {
  echo "Waiting for HTTP 200 and the expected response..."
  while true; do
    if ! kill -0 "$server_pid" 2>/dev/null; then
      echo "The HTTP server exited; startup failed." >&2
      cat "$log_dir/server.log" >&2
      return 1
    fi
    if node <<'NODE'
const http = require('node:http');
const request = http.get({
  hostname: '127.0.0.1',
  port: process.env.PORT,
  // Exercise a non-local Host header as used by the public preview proxy.
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
      echo "Healthcheck passed: HTTP 200, response ok."
      return 0
    fi
    echo "HTTP server is not ready yet; checking again shortly..."
    sleep 2
  done
}

if [ "${AIR_STARTUP_MODE:-}" = warmup ]; then
  healthcheck
fi
