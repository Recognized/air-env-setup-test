#!/usr/bin/env bash
set -euo pipefail

readonly app_port="${PORT:-3000}"
readonly app_log="${TMPDIR:-/tmp}/air-env-setup-test.log"

_ps="$(ps -ax -o args= 2>/dev/null)"
if grep -q 'dind.sh air-workspace-start.sh' <<<"$_ps"; then
  WARMUP=
else
  WARMUP=1
fi

healthcheck() {
  local response

  while ! response="$(curl --silent --show-error --fail "http://127.0.0.1:${app_port}/" 2>/dev/null)"; do
    if ! kill -0 "$app_pid" 2>/dev/null; then
      wait "$app_pid"
      return 1
    fi
    sleep 1
  done

  [[ "$response" == "ok" ]]
}

# There are currently no third-party dependencies, but this validates and primes
# the repository's npm metadata/cache if dependencies are added later.
npm install --ignore-scripts --no-audit --no-fund --package-lock=false

# Runtime processes are not included in the warm snapshot, so start the app on
# every boot. The task run returns immediately after spawning it.
npm start >"$app_log" 2>&1 &
app_pid=$!

if [[ -n "${WARMUP:-}" ]]; then
  healthcheck
fi
