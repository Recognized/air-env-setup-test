#!/usr/bin/env bash
set -euo pipefail

cd "$(git rev-parse --show-toplevel)"

# Keep the dependency cache warm even though this intentionally tiny fixture
# currently has no third-party packages.
npm install --ignore-scripts --no-audit --no-fund

port="${PORT:-3000}"
pid_file="/tmp/air-env-setup-test.pid"
log_file="/tmp/air-env-setup-test.log"

if [[ -f "$pid_file" ]] && kill -0 "$(<"$pid_file")" 2>/dev/null; then
  : # The service is already running.
else
  nohup env PORT="$port" npm start >"$log_file" 2>&1 &
  echo "$!" >"$pid_file"
fi

_ps="$(ps -ax -o args= 2>/dev/null)"
if ! grep -q 'dind.sh air-workspace-start.sh' <<<"$_ps"; then
  PORT="$port" bash "$(dirname "$0")/healthcheck.sh"
fi
