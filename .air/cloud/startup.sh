#!/usr/bin/env bash
set -euo pipefail

# Air may execute a materialized copy of this script outside the checkout.
cd "$(git rev-parse --show-toplevel)"

echo 'Checking Node.js and required configuration...'
node --version
npm --version
if [[ -z "${API_KEY:-}" || -z "${DATABASE_PASSWORD:-}" ]]; then
  echo 'Missing required secrets: configure API_KEY and DATABASE_PASSWORD in Air.' >&2
  exit 1
fi

# This app uses only Node.js built-ins, so no dependency install is needed.
export PORT="${PORT:-3000}"
log_dir="${HOME}/.cache/air-env-setup-test"
mkdir -p "$log_dir"
echo "Starting HTTP server on port ${PORT} (log: ${log_dir}/server.log)..."
nohup node app.js >"${log_dir}/server.log" 2>&1 < /dev/null &
server_pid=$!

healthcheck() {
  local response
  while true; do
    if ! kill -0 "$server_pid" 2>/dev/null; then
      echo 'HTTP server exited before readiness. Server log:' >&2
      cat "${log_dir}/server.log" >&2
      return 1
    fi
    if response=$(curl --noproxy '*' --silent --show-error --fail \
      --header 'Host: air-preview.example' \
      --write-out '\n%{http_code}' "http://127.0.0.1:${PORT}/") && \
      [[ "$response" == $'ok\n\n200' ]]; then
      echo 'Healthcheck passed: HTTP 200 with expected ok response.'
      return 0
    fi
    echo 'Waiting for the HTTP server to return the expected response...'
    sleep 2
  done
}

if [[ "${AIR_STARTUP_MODE:-}" == warmup ]]; then
  healthcheck
fi
