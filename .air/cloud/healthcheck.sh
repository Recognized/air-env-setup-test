#!/usr/bin/env bash
set -euo pipefail

: "${API_KEY:?API_KEY is required}"
: "${DATABASE_PASSWORD:?DATABASE_PASSWORD is required}"

port="${PORT:-3000}"
url="http://127.0.0.1:${port}/"

for _ in $(seq 1 30); do
  response="$(curl --fail --silent --show-error --max-time 2 "$url" 2>/dev/null || true)"
  if [ "$response" = "ok" ]; then
    exit 0
  fi
  sleep 1
done

echo "Health check failed: $url did not return the expected response within 30 seconds." >&2
exit 1
