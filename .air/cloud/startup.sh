#!/usr/bin/env bash
set -euo pipefail

repo_root="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
cd "$repo_root"

# Fail early if the base workspace ever stops providing the only toolchain this
# dependency-free project needs, and prime Node's parser cache while warming up.
command -v node >/dev/null
node --check app.js

mkdir -p /tmp/air-env-setup-test
if ! pgrep -f '[n]ode app.js' >/dev/null; then
  nohup npm start > /tmp/air-env-setup-test/server.log 2>&1 &
  echo "$!" > /tmp/air-env-setup-test/server.pid
fi

process_tree="$(ps -ax -o args= 2>/dev/null || true)"
if ! grep -q 'dind.sh air-workspace-start.sh' <<<"$process_tree"; then
  bash "$repo_root/.air/cloud/healthcheck.sh"
fi
