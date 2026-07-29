#!/usr/bin/env bash
set -euo pipefail

port="${PORT:-3000}"
url="http://127.0.0.1:${port}/"
deadline=$((SECONDS + 30))

while (( SECONDS < deadline )); do
  if response="$(curl --fail --silent --show-error --max-time 2 "$url" 2>/dev/null)" \
    && [[ "$response" == "ok" ]]; then
    echo "air-env-setup-test is healthy at $url"
    exit 0
  fi
  sleep 1
done

echo "Health check timed out waiting for $url" >&2
[[ -f /tmp/air-env-setup-test.log ]] && tail -n 50 /tmp/air-env-setup-test.log >&2
exit 1
