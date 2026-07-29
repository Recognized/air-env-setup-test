#!/usr/bin/env bash
set -euo pipefail

port="${PORT:-3000}"
deadline=$((SECONDS + 20))

while (( SECONDS < deadline )); do
  if response="$(curl --fail --silent --show-error --max-time 2 "http://127.0.0.1:${port}/" 2>/dev/null)"; then
    if [ "$response" = "ok" ]; then
      exit 0
    fi
    echo "Unexpected response from service: $response" >&2
    exit 1
  fi
  sleep 0.25
done

echo "Service did not become healthy on port ${port} within 20 seconds." >&2
runtime_dir="${TMPDIR:-/tmp}/air-env-setup-test"
if [ -f "$runtime_dir/server.log" ]; then
  tail -n 50 "$runtime_dir/server.log" >&2
fi
exit 1
