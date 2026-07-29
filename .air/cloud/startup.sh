#!/usr/bin/env bash
set -euo pipefail

repo_root="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
cd "$repo_root"

command -v node >/dev/null
command -v npm >/dev/null
node --check app.js

if [ -z "${API_KEY:-}" ] || [ -z "${DATABASE_PASSWORD:-}" ]; then
  echo "API_KEY and DATABASE_PASSWORD must be configured." >&2
  exit 1
fi

runtime_dir="${TMPDIR:-/tmp}/air-env-setup-test"
mkdir -p "$runtime_dir"

if [ -f "$runtime_dir/server.pid" ] && kill -0 "$(cat "$runtime_dir/server.pid")" 2>/dev/null; then
  kill "$(cat "$runtime_dir/server.pid")"
  for _ in $(seq 1 20); do
    kill -0 "$(cat "$runtime_dir/server.pid")" 2>/dev/null || break
    sleep 0.1
  done
fi

nohup npm start >"$runtime_dir/server.log" 2>&1 &
echo $! >"$runtime_dir/server.pid"

process_tree="$(ps -ax -o args= 2>/dev/null || true)"
if ! grep -q 'dind.sh air-workspace-start.sh' <<<"$process_tree"; then
  bash "$repo_root/.air/cloud/healthcheck.sh"
fi
