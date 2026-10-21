#!/usr/bin/env bash
set -euo pipefail

if [ "${AIR_STARTUP_MODE:-}" = "warmup" ]; then
  WARMUP=1
else
  WARMUP=
fi

APP_PORT="${PORT:-3000}"
AIR_TMP_DIR="${PWD}/.air/tmp"
SERVER_LOG="${AIR_TMP_DIR}/server.log"
SERVER_PID_FILE="${AIR_TMP_DIR}/server.pid"

mkdir -p "$AIR_TMP_DIR"

start_server() {
  if [ -f "$SERVER_PID_FILE" ]; then
    existing_pid="$(cat "$SERVER_PID_FILE" 2>/dev/null || true)"
    if [ -n "${existing_pid:-}" ] && kill -0 "$existing_pid" 2>/dev/null; then
      echo "Node server already running on port ${APP_PORT}."
      return
    fi
  fi

  echo "Starting Node server on 0.0.0.0:${APP_PORT}."
  PORT="$APP_PORT" HOST=0.0.0.0 npm start >"$SERVER_LOG" 2>&1 &
  echo "$!" >"$SERVER_PID_FILE"
}

healthcheck() {
  echo "Waiting for Node server health check on port ${APP_PORT}."
  while true; do
    if curl -fsS "http://127.0.0.1:${APP_PORT}/" | grep -qx "ok"; then
      echo "Node server health check passed."
      return 0
    fi

    if [ -f "$SERVER_PID_FILE" ]; then
      server_pid="$(cat "$SERVER_PID_FILE" 2>/dev/null || true)"
      if [ -n "${server_pid:-}" ] && ! kill -0 "$server_pid" 2>/dev/null; then
        echo "Node server exited before becoming healthy. Recent log output:"
        tail -50 "$SERVER_LOG" 2>/dev/null || true
        return 1
      fi
    fi

    echo "Server is not ready yet; checking again soon."
    sleep 2
  done
}

node --version
npm --version
start_server

if [ -n "${WARMUP:-}" ]; then
  healthcheck
fi
