#!/usr/bin/env bash
set -euo pipefail

# Air materializes this script outside the checkout; startup runs from the repo.
if [[ -f "$(dirname "${BASH_SOURCE[0]}")/../../app.js" ]]; then
  cd "$(dirname "${BASH_SOURCE[0]}")/../.."
fi

command -v node >/dev/null || { echo "Node.js is required in the workspace image." >&2; exit 1; }
: "${API_KEY:?Provide API_KEY in the Air environment secrets}"
: "${DATABASE_PASSWORD:?Provide DATABASE_PASSWORD in the Air environment secrets}"
export PORT="${PORT:-3000}"

# This app uses only Node built-ins: there are no dependencies to install.
echo "Starting HTTP app on port $PORT with $(node --version)"
log_dir="${HOME}/.cache/air-env-setup-test"
mkdir -p "$log_dir"
nohup node app.js >"$log_dir/server.log" 2>&1 < /dev/null &
server_pid=$!

healthcheck() {
  echo "Waiting for HTTP 200 and the expected response..."
  while true; do
    if ! kill -0 "$server_pid" 2>/dev/null; then
      echo "HTTP server exited; startup failed." >&2
      cat "$log_dir/server.log" >&2
      return 1
    fi
    if node <<'JS'
const http = require('node:http');
const request = http.get({
  hostname: '127.0.0.1', port: process.env.PORT, path: '/',
  headers: { Host: 'preview.orca-proxy-staging.labs.jb.gg' }
}, response => {
  let body = '';
  response.setEncoding('utf8');
  response.on('data', chunk => { body += chunk; });
  response.on('end', () => process.exit(response.statusCode === 200 && body === 'ok\n' ? 0 : 1));
  response.on('error', () => process.exit(1));
});
request.on('error', () => process.exit(1));
JS
    then
      echo "Healthcheck passed: HTTP 200, body ok."
      return 0
    fi
    echo "HTTP app is not ready yet; waiting..."
    sleep 2
  done
}

# Runtime processes must restart after a snapshot; only warmup blocks on readiness.
if [[ "${AIR_STARTUP_MODE:-}" == warmup ]]; then
  healthcheck
fi
