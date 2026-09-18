#!/usr/bin/env bash
set -euo pipefail

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
cd "$REPO_ROOT"

: "${API_KEY:?API_KEY must be set}"
: "${DATABASE_PASSWORD:?DATABASE_PASSWORD must be set}"

PORT="${PORT:-3000}"
LOG_FILE="/tmp/air-env-setup-test.log"

nohup npm start > "$LOG_FILE" 2>&1 &
echo $! > /tmp/air-env-setup-test.pid

for i in $(seq 1 30); do
  if curl -sf "http://localhost:${PORT}/" > /dev/null; then
    echo "air-env-setup-test is up on port ${PORT}"
    exit 0
  fi
  sleep 1
done

echo "air-env-setup-test failed to start" >&2
cat "$LOG_FILE" >&2
exit 1
