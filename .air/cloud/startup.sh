#!/usr/bin/env bash
set -euo pipefail

repo_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
cd "$repo_dir"

# Keep this step even though the project currently has no dependencies: it validates
# the manifest and primes npm's on-disk cache when dependencies are added later.
npm install --ignore-scripts --no-audit --no-fund

runtime_dir="${TMPDIR:-/tmp}/air-env-setup-test"
mkdir -p "$runtime_dir"

# A snapshotted environment does not preserve processes, so launch the service on
# every boot. Avoid starting a duplicate when the script is rerun interactively.
if ! bash "$repo_dir/.air/cloud/healthcheck.sh" >/dev/null 2>&1; then
  nohup npm start >"$runtime_dir/server.log" 2>&1 &
  echo $! >"$runtime_dir/server.pid"
fi

process_tree="$(ps -ax -o args= 2>/dev/null || true)"
if ! grep -q 'dind.sh air-workspace-start.sh' <<<"$process_tree"; then
  bash "$repo_dir/.air/cloud/healthcheck.sh"
fi
