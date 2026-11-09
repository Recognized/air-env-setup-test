#!/usr/bin/env bash
# Environment startup script for air-env-setup-test.
# Requires secrets API_KEY and DATABASE_PASSWORD (provided as environment variables).
set -euo pipefail

REPO_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
cd "$REPO_DIR"

# No npm dependencies today; install only if some are added later.
if [ -f package-lock.json ]; then
  npm ci --no-audit --no-fund
elif grep -q '"dependencies"\|"devDependencies"' package.json; then
  npm install --no-audit --no-fund
fi

healthcheck() {
  local missing=()
  [ -n "${API_KEY:-}" ] || missing+=(API_KEY)
  [ -n "${DATABASE_PASSWORD:-}" ] || missing+=(DATABASE_PASSWORD)
  if [ ${#missing[@]} -gt 0 ]; then
    echo "healthcheck: missing required secrets: ${missing[*]}" >&2
    return 1
  fi

  local port="${HEALTHCHECK_PORT:-3917}"
  local log; log="$(mktemp)"
  PORT="$port" node app.js >"$log" 2>&1 &
  local pid=$!
  local ok=1
  for _ in $(seq 1 50); do
    if ! kill -0 "$pid" 2>/dev/null; then break; fi
    if [ "$(curl -fsS "http://127.0.0.1:${port}/" 2>/dev/null)" = "ok" ]; then ok=0; break; fi
    sleep 0.2
  done
  kill "$pid" 2>/dev/null || true
  wait "$pid" 2>/dev/null || true
  if [ $ok -ne 0 ]; then
    echo "healthcheck: app failed to respond. Log:" >&2
    cat "$log" >&2
  else
    echo "healthcheck: app responded ok"
  fi
  rm -f "$log"
  return $ok
}

healthcheck
