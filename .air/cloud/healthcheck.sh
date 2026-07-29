#!/usr/bin/env bash
set -euo pipefail

if [ -z "${API_KEY:-}" ] || [ -z "${DATABASE_PASSWORD:-}" ]; then
  echo "Required Air secrets are unavailable." >&2
  exit 1
fi

port="${PORT:-3000}"
for _ in $(seq 1 30); do
  if response="$(curl --fail --silent --show-error --connect-timeout 1 --max-time 2 \
    "http://127.0.0.1:${port}/" 2>/dev/null)" \
    && [ "$response" = "ok" ]; then
    exit 0
  fi
  sleep 1
done

echo "App did not become healthy on port ${port}." >&2
if [ -f /tmp/air-env-setup-test.log ]; then
  tail -n 50 /tmp/air-env-setup-test.log >&2
fi
exit 1
