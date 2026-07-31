#!/usr/bin/env bash
set -euo pipefail

repo_root="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
cd "$repo_root"

# Prime npm's cache even though this deliberately minimal app currently has no
# third-party dependencies.
npm install --ignore-scripts --package-lock=false

processes="$(ps -ax -o args= 2>/dev/null || true)"
if grep -q 'dind.sh air-workspace-start.sh' <<<"$processes"; then
  warmup=""
else
  warmup=1
fi

port="${PORT:-3000}"
pid_file="/tmp/air-env-setup-test-${port}.pid"
log_file="/tmp/air-env-setup-test-${port}.log"

if ! curl -fsS "http://127.0.0.1:${port}" >/dev/null 2>&1; then
  nohup npm start >"$log_file" 2>&1 &
  echo "$!" >"$pid_file"
fi

if [[ -n "$warmup" ]]; then
  bash "$(dirname "${BASH_SOURCE[0]}")/healthcheck.sh"
fi
