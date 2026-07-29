#!/usr/bin/env bash
set -euo pipefail

repo_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
cd "$repo_dir"

# This repository has no dependencies, but npm install validates the manifest and
# primes npm's local metadata/cache if dependencies are added later.
npm install --ignore-scripts --no-audit --no-fund

port="${PORT:-3000}"
log_dir="${AIR_ARTIFACTS_DIR:-/tmp/air-env-setup-test}"
mkdir -p "$log_dir"

nohup npm start >"$log_dir/server.log" 2>&1 &
echo $! >"$log_dir/server.pid"

process_tree="$(ps -ax -o args= 2>/dev/null || true)"
if ! grep -q 'dind.sh air-workspace-start.sh' <<<"$process_tree"; then
  bash "$repo_dir/.air/cloud/healthcheck.sh"
fi
