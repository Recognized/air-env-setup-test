#!/usr/bin/env bash
set -euo pipefail

cd "$(git rev-parse --show-toplevel 2>/dev/null || pwd)"

echo "Node: $(node --version)"
echo "npm: $(npm --version)"

missing=()
for key in API_KEY DATABASE_PASSWORD; do
  if [ -z "${!key:-}" ]; then
    missing+=("$key")
  fi
done

if [ "${#missing[@]}" -gt 0 ]; then
  printf 'Missing required secret environment variables: %s\n' "${missing[*]}" >&2
  exit 1
fi

node -e "require('./app.js')" &
app_pid=$!

cleanup() {
  kill "$app_pid" 2>/dev/null || true
}
trap cleanup EXIT

for _ in $(seq 1 20); do
  if node -e "require('http').get('http://127.0.0.1:' + (process.env.PORT || 3000), res => process.exit(res.statusCode === 200 ? 0 : 1)).on('error', () => process.exit(1))"; then
    echo "Startup smoke test passed."
    exit 0
  fi
  sleep 0.5
done

echo "Startup smoke test failed: server did not respond." >&2
exit 1
