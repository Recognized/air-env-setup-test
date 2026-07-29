#!/usr/bin/env bash
set -euo pipefail

repo_root="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
cd "$repo_root"

command -v node >/dev/null
command -v npm >/dev/null

# Populate npm's cache and validate the package metadata. This project currently
# has no dependencies, so avoid creating a lockfile in the working tree.
npm install --ignore-scripts --no-audit --no-fund --package-lock=false

processes="$(ps -ax -o args= 2>/dev/null || true)"
if grep -q 'dind.sh air-workspace-start.sh' <<<"$processes"; then
  warmup=""
else
  warmup=1
fi

if ! curl --silent --fail --max-time 2 http://127.0.0.1:3000/ >/dev/null 2>&1; then
  nohup npm start > /tmp/air-env-setup-test.log 2>&1 &
fi

if [[ -n "$warmup" ]]; then
  bash "$repo_root/.air/cloud/healthcheck.sh"
fi
