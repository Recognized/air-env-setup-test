#!/usr/bin/env bash
set -euo pipefail

repo_root="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
runtime_dir="$repo_root/.air/runtime"
pid_file="$runtime_dir/app.pid"
log_file="$runtime_dir/app.log"

command -v node >/dev/null
mkdir -p "$runtime_dir"

if [ -f "$pid_file" ] && kill -0 "$(cat "$pid_file")" 2>/dev/null; then
  : # The development server is already running.
else
  cd "$repo_root"
  nohup npm start >"$log_file" 2>&1 &
  echo "$!" >"$pid_file"
fi

processes="$(ps -ax -o args= 2>/dev/null)"
if ! grep -q 'dind.sh air-workspace-start.sh' <<<"$processes"; then
  bash "$repo_root/.air/cloud/healthcheck.sh"
fi
