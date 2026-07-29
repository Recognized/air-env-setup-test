#!/usr/bin/env bash
set -euo pipefail

cd "$(git rev-parse --show-toplevel)"

# This project has no third-party dependencies, but checking the toolchain here
# fails early with a useful error if the workspace image ever loses Node.js.
node --version
npm --version

if [ -z "${API_KEY:-}" ] || [ -z "${DATABASE_PASSWORD:-}" ]; then
  echo "API_KEY and DATABASE_PASSWORD must be configured as Air secrets." >&2
  exit 1
fi

if ! pgrep -f '[n]ode app.js' >/dev/null; then
  nohup npm start > /tmp/air-env-setup-test.log 2>&1 &
fi

_ps="$(ps -ax -o args= 2>/dev/null)"
if ! grep -q 'dind.sh air-workspace-start.sh' <<<"$_ps"; then
  bash "$(dirname "$0")/healthcheck.sh"
fi
