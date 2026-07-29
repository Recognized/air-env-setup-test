#!/usr/bin/env bash
set -euo pipefail

repo_root="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
cd "$repo_root"

node --version
npm --version

if [ -f package-lock.json ]; then
  npm ci
else
  npm install --ignore-scripts --no-audit --no-fund
fi

_ps="$(ps -ax -o args= 2>/dev/null)"
if grep -q 'dind.sh air-workspace-start.sh' <<<"$_ps"; then
  WARMUP=
else
  WARMUP=1
fi

mkdir -p .air/cloud/run
nohup npm start >.air/cloud/run/server.log 2>&1 &
echo "$!" >.air/cloud/run/server.pid

if [ -n "${WARMUP:-}" ]; then
  bash "$repo_root/.air/cloud/healthcheck.sh"
fi
