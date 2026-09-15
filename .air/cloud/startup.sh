#!/usr/bin/env bash
set -euo pipefail

cd "$(dirname "${BASH_SOURCE[0]}")/../.."

# Node and npm are supplied by the Air workspace image. This app currently
# uses only Node built-ins, so there are no packages or build caches to prime.
command -v node >/dev/null || { echo "Node.js is required in the workspace image." >&2; exit 1; }
command -v npm >/dev/null || { echo "npm is required in the workspace image." >&2; exit 1; }
node --version
npm --version
node --check app.js

if [[ -z "${API_KEY:-}" || -z "${DATABASE_PASSWORD:-}" ]]; then
  echo "Configure API_KEY and DATABASE_PASSWORD as personal secrets in Air." >&2
  exit 1
fi

runtime_dir="${HOME}/.cache/air-env-setup-test"
mkdir -p "$runtime_dir"
server_pid=
if [[ -f "$runtime_dir/server.pid" ]]; then
  read -r server_pid < "$runtime_dir/server.pid" || true
fi

# Reuse only a live instance of this repository's server.
if [[ ! "$server_pid" =~ ^[0-9]+$ ]] ||
   ! kill -0 "$server_pid" 2>/dev/null ||
   [[ "$(readlink "/proc/$server_pid/cwd" 2>/dev/null || true)" != "$PWD" ]] ||
   [[ "$(tr '\0' ' ' < "/proc/$server_pid/cmdline" 2>/dev/null || true)" != "node app.js " ]]; then
  echo "Starting HTTP server on port ${PORT:-3000}."
  nohup node app.js > "$runtime_dir/server.log" 2>&1 < /dev/null &
  server_pid=$!
  echo "$server_pid" > "$runtime_dir/server.pid"
fi
echo "Server log: $runtime_dir/server.log"

healthcheck() {
  echo "Waiting for the HTTP server to return 200 and ok."
  while true; do
    if ! kill -0 "$server_pid" 2>/dev/null; then
      echo "HTTP server exited; startup failed." >&2
      cat "$runtime_dir/server.log" >&2
      return 1
    fi
    if node <<'NODE'
const http = require('node:http');
http.get({
  hostname: '127.0.0.1',
  port: process.env.PORT || 3000,
  path: '/',
  headers: { Host: 'air-preview.example' }
}, response => {
  let body = '';
  response.setEncoding('utf8');
  response.on('data', chunk => body += chunk);
  response.on('end', () => {
    process.exit(response.statusCode === 200 && body === 'ok\n' ? 0 : 1);
  });
  response.on('error', () => process.exit(1));
}).on('error', () => process.exit(1));
NODE
    then
      echo "Healthcheck passed: HTTP 200, body ok."
      return 0
    fi
    echo "HTTP server is not ready yet; waiting."
    sleep 2
  done
}

# Tasks can begin while the server starts; snapshot baking waits for readiness.
if [[ "${AIR_STARTUP_MODE:-}" == warmup ]]; then
  healthcheck
fi
