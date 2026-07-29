#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"
RUNTIME_DIR="${XDG_RUNTIME_DIR:-/tmp}/air-env-setup-test"
mkdir -p "$RUNTIME_DIR"

command -v node >/dev/null

_ps="$(ps -ax -o args= 2>/dev/null || true)"
if grep -q 'dind.sh air-workspace-start.sh' <<<"$_ps"; then
  WARMUP=
else
  WARMUP=1
fi

if ! curl --fail --silent "http://127.0.0.1:${PORT:-3000}/" >/dev/null 2>&1; then
  cd "$REPO_ROOT"
  nohup npm start >"$RUNTIME_DIR/server.log" 2>&1 &
  echo "$!" >"$RUNTIME_DIR/server.pid"
fi

if [[ -n "${WARMUP:-}" ]]; then
  bash "$SCRIPT_DIR/healthcheck.sh"
fi
