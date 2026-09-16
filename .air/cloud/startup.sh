#!/usr/bin/env bash
set -euo pipefail

cd "$(dirname "${BASH_SOURCE[0]}")/../.."
if [[ -z "${API_KEY:-}" || -z "${DATABASE_PASSWORD:-}" ]]; then
  echo 'Missing required secrets: configure API_KEY and DATABASE_PASSWORD in Air.' >&2
  exit 1
fi

# This app uses only Node's standard library: there are no packages to install.
echo "Using Node $(node --version)"
node --check app.js
log_dir="${HOME}/.cache/air-env-setup-test"
mkdir -p "$log_dir"
echo "Starting the app on port ${PORT:-3000}; log: $log_dir/server.log"
nohup node app.js >"$log_dir/server.log" 2>&1 < /dev/null &
server_pid=$!

healthcheck() {
  echo 'Waiting for HTTP 200 and the expected application response...'
  while true; do
    if ! kill -0 "$server_pid" 2>/dev/null; then
      echo 'The app exited before readiness. Server output:' >&2
      cat "$log_dir/server.log" >&2
      return 1
    fi
    if node <<'JS'
const http = require('http');
const req = http.get({
  hostname: '127.0.0.1',
  port: process.env.PORT || 3000,
  path: '/',
  headers: { Host: 'air-preview.example' }
}, res => {
  let body = '';
  res.setEncoding('utf8');
  res.on('data', chunk => body += chunk);
  res.on('end', () => process.exit(res.statusCode === 200 && body === 'ok\n' ? 0 : 1));
});
req.on('error', () => process.exit(1));
JS
    then
      echo 'Healthcheck passed: HTTP 200, body ok.'
      return 0
    fi
    echo 'App is not ready yet; checking again...'
    sleep 2
  done
}

# Only warmup waits for readiness; task launches return promptly.
if [[ "${AIR_STARTUP_MODE:-}" == warmup ]]; then
  healthcheck
fi
