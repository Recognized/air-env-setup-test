#!/usr/bin/env bash
set -euo pipefail

port="${PORT:-3000}"
url="http://127.0.0.1:${port}/"
deadline=$((SECONDS + 30))

while (( SECONDS < deadline )); do
  response="$(curl --silent --show-error --max-time 2 "$url" 2>/dev/null || true)"
  if [[ "$response" == "ok" ]]; then
    exit 0
  fi
  sleep 1
done

echo "Health check failed: $url did not return 'ok' within 30 seconds." >&2
if [[ -f /tmp/air-env-setup-test/server.log ]]; then
  tail -n 50 /tmp/air-env-setup-test/server.log >&2
fi
exit 1
