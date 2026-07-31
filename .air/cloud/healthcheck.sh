#!/usr/bin/env bash
set -euo pipefail

port="${PORT:-3000}"
url="http://127.0.0.1:${port}"

for _ in {1..40}; do
  response="$(curl -fsS "$url" 2>/dev/null || true)"
  if [[ "$response" == "ok" ]]; then
    echo "air-env-setup-test is healthy at $url"
    exit 0
  fi
  sleep 0.25
done

echo "air-env-setup-test did not return the expected response from $url" >&2
log_file="/tmp/air-env-setup-test-${port}.log"
if [[ -f "$log_file" ]]; then
  cat "$log_file" >&2
fi
exit 1
