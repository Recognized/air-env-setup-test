#!/usr/bin/env bash
set -euo pipefail

repo_dir="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/../.." && pwd)"
cd "$repo_dir"

: "${API_KEY:?Set API_KEY through the Air environment secrets dialog}"
: "${DATABASE_PASSWORD:?Set DATABASE_PASSWORD through the Air environment secrets dialog}"
export PORT="${PORT:-3000}"

echo "Checking Node.js runtime..."
node --version
# This application uses only Node built-ins; there are no packages to install.
node --check app.js

state_dir="${XDG_CACHE_HOME:-$HOME/.cache}/air-env-setup-test"
mkdir -p "$state_dir"
log_file="$state_dir/server.log"
pid_file="$state_dir/server.pid"

# Reuse only this repository's server when startup is invoked again in one boot.
server_pid=""
if [[ -f "$pid_file" ]]; then
  read -r previous_pid < "$pid_file" || true
  if [[ "${previous_pid:-}" =~ ^[0-9]+$ ]] && kill -0 "$previous_pid" 2>/dev/null &&
    [[ "$(readlink "/proc/$previous_pid/cwd" 2>/dev/null)" = "$repo_dir" ]] &&
    tr '\0' '\n' < "/proc/$previous_pid/cmdline" | grep -Fxq "$repo_dir/app.js"; then
    server_pid="$previous_pid"
  fi
fi

if [[ -z "$server_pid" ]]; then
  echo "Starting HTTP app on port $PORT (log: $log_file)..."
  nohup node "$repo_dir/app.js" > "$log_file" 2>&1 < /dev/null &
  server_pid=$!
  echo "$server_pid" > "$pid_file"
fi

healthcheck() {
  echo "Waiting for HTTP 200 and the expected response..."
  while true; do
    if ! kill -0 "$server_pid" 2>/dev/null; then
      echo "HTTP app exited before readiness. Server output:" >&2
      cat "$log_file" >&2
      return 1
    fi
    if node <<'NODE'
const http = require('node:http');
const req = http.get({
  hostname: '127.0.0.1',
  port: process.env.PORT,
  path: '/',
  headers: { Host: 'air-preview.example' },
}, (res) => {
  let body = '';
  res.setEncoding('utf8');
  res.on('data', chunk => { body += chunk; });
  res.on('end', () => process.exit(res.statusCode === 200 && body === 'ok\n' ? 0 : 1));
  res.on('error', () => process.exit(1));
});
req.on('error', () => process.exit(1));
NODE
    then
      echo "Healthcheck passed: HTTP 200, body ok."
      return 0
    fi
    echo "HTTP app is not ready yet; checking again..."
    sleep 2
  done
}

if [[ "${AIR_STARTUP_MODE:-}" = warmup ]]; then
  healthcheck
else
  echo "HTTP app started in the background."
fi
