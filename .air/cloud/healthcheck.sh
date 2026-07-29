#!/usr/bin/env bash
set -euo pipefail

URL="http://127.0.0.1:${PORT:-3000}/"
deadline=$((SECONDS + 30))

while (( SECONDS < deadline )); do
  response="$(curl --fail --silent --max-time 2 "$URL" 2>/dev/null || true)"
  if [[ "$response" == "ok" ]]; then
    exit 0
  fi
  sleep 1
done

echo "Health check failed: $URL did not return 'ok' within 30 seconds." >&2
exit 1
