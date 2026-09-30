#!/bin/bash
set -e

# Determine if we're in warmup mode (snapshot-baking) or task mode (real run)
if [ "${AIR_STARTUP_MODE:-}" = warmup ]; then
  WARMUP=1
else
  WARMUP=
fi

echo "Installing Node.js dependencies..."
npm install

echo "Startup complete. Environment ready."

healthcheck() {
  echo "Running healthcheck: verifying app starts and responds..."

  # Start the app in the background
  PORT=3000 npm start > /tmp/app.log 2>&1 &
  APP_PID=$!

  # Wait for the app to be ready
  local max_attempts=30
  local attempt=0

  while [ $attempt -lt $max_attempts ]; do
    attempt=$((attempt + 1))

    # Try to connect to the server
    if curl -s http://localhost:3000/ > /dev/null 2>&1; then
      echo "✓ App is responding on port 3000"
      kill $APP_PID 2>/dev/null || true
      return 0
    fi

    # Check if the process is still alive
    if ! kill -0 $APP_PID 2>/dev/null; then
      echo "✗ App process died unexpectedly. Last logs:"
      tail -20 /tmp/app.log
      return 1
    fi

    echo "  Waiting for app to be ready (attempt $attempt/$max_attempts)..."
    sleep 1
  done

  echo "✗ App did not respond after $max_attempts attempts"
  kill $APP_PID 2>/dev/null || true
  tail -20 /tmp/app.log
  return 1
}

# On warmup, block until healthcheck passes
if [ -n "${WARMUP:-}" ]; then
  healthcheck
fi
