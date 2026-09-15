#!/usr/bin/env bash
set -euo pipefail

# Air may materialize this script outside the checkout; launch from the repo.
cd "$(git rev-parse --show-toplevel)"

command -v node >/dev/null || { echo 'Node.js is required in the workspace image.' >&2; exit 1; }
if [[ -z ${API_KEY:-} || -z ${DATABASE_PASSWORD:-} ]]; then
  echo 'Set API_KEY and DATABASE_PASSWORD through Air environment secrets.' >&2
  exit 1
fi

export PORT="${PORT:-3000}"
log_dir="${HOME}/.cache/air-env-setup-test"
mkdir -p "$log_dir"
echo "Starting HTTP server on port $PORT with $(node --version)."
# There are no external dependencies or build artifacts to install or cache.
nohup node app.js >"$log_dir/server.log" 2>&1 < /dev/null &
server_pid=$!

healthcheck() {
  echo 'Waiting for HTTP 200 and the expected response body.'
  while true; do
    if ! kill -0 "$server_pid" 2>/dev/null; then
      echo "Server exited; inspect $log_dir/server.log." >&2
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
      echo 'Healthcheck passed: HTTP 200, body ok.'
      return 0
    fi
    echo 'Server is not ready yet; checking again in 2 seconds.'
    sleep 2
  done
}

if [[ ${AIR_STARTUP_MODE:-} == warmup ]]; then
  healthcheck
fi
