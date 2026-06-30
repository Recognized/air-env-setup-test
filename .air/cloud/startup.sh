#!/usr/bin/env bash
set -euo pipefail

repo_root="$(git rev-parse --show-toplevel 2>/dev/null || pwd)"
cd "$repo_root"

: "${API_KEY:?API_KEY must be configured in the Air environment secrets.}"
: "${DATABASE_PASSWORD:?DATABASE_PASSWORD must be configured in the Air environment secrets.}"

if ! command -v node >/dev/null 2>&1; then
  echo "Node.js is required but was not found on PATH." >&2
  exit 1
fi

if ! command -v npm >/dev/null 2>&1; then
  echo "npm is required but was not found on PATH." >&2
  exit 1
fi

echo "Using Node $(node --version)"
echo "Using npm $(npm --version)"

if [ -f package-lock.json ]; then
  npm ci
elif node -e "const p = require('./package.json'); const hasDeps = ['dependencies', 'devDependencies', 'optionalDependencies'].some((key) => p[key] && Object.keys(p[key]).length); process.exit(hasDeps ? 0 : 1);"; then
  npm install
else
  echo "No package dependencies to install."
fi

node --check app.js

port="${PORT:-3000}"
log_file="/tmp/air-env-setup-test-server.log"
rm -f "$log_file"

node app.js >"$log_file" 2>&1 &
server_pid="$!"

cleanup() {
  if kill -0 "$server_pid" >/dev/null 2>&1; then
    kill "$server_pid" >/dev/null 2>&1 || true
    wait "$server_pid" >/dev/null 2>&1 || true
  fi
}
trap cleanup EXIT

for _ in $(seq 1 30); do
  if node -e "const http = require('http'); const req = http.get({ host: '127.0.0.1', port: Number(process.argv[1]), path: '/', timeout: 1000 }, (res) => { res.resume(); process.exit(res.statusCode === 200 ? 0 : 1); }); req.on('timeout', () => req.destroy(new Error('timeout'))); req.on('error', () => process.exit(1));" "$port"; then
    echo "Server smoke test passed on port ${port}."
    exit 0
  fi

  if ! kill -0 "$server_pid" >/dev/null 2>&1; then
    echo "Server exited before the smoke test completed." >&2
    cat "$log_file" >&2 || true
    exit 1
  fi

  sleep 1
done

echo "Server did not respond on port ${port}." >&2
cat "$log_file" >&2 || true
exit 1
