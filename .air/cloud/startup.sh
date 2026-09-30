#!/bin/bash
set -e

echo "Starting environment setup..."

# Detect startup mode
if [ "${AIR_STARTUP_MODE:-}" = warmup ]; then
  WARMUP=1
else
  WARMUP=
fi

# Ensure Node.js and npm are available
if ! command -v node &> /dev/null; then
  echo "Installing Node.js..."
  curl -fsSL https://deb.nodesource.com/setup_lts.x | sudo -E bash -
  sudo apt-get install -y nodejs
fi

echo "Node.js version: $(node --version)"
echo "npm version: $(npm --version)"

# Install dependencies
echo "Installing dependencies..."
cd /workspaces/air-env-setup-test
npm install

# Start the application
echo "Starting the application..."
if [ -n "${WARMUP:-}" ]; then
  # In warmup mode, start the app and wait for healthcheck
  PORT=3000 nohup npm start >/tmp/app.log 2>&1 &
  APP_PID=$!
  echo "App started with PID $APP_PID (warmup mode)"
else
  # In task mode, start the app in the background and exit promptly
  PORT=3000 nohup npm start >/tmp/app.log 2>&1 &
  echo "App started in background (task mode)"
  sleep 1
  exit 0
fi

# Healthcheck function - verify the app is running and responsive
healthcheck() {
  local max_attempts=30
  local attempt=0

  echo "Running health check..."

  while [ $attempt -lt $max_attempts ]; do
    attempt=$((attempt + 1))

    if curl -sf http://localhost:3000/ >/dev/null 2>&1; then
      echo "✓ Health check passed - app is responding on port 3000"
      return 0
    fi

    echo "Health check attempt $attempt/$max_attempts: waiting for app to start..."
    sleep 1
  done

  echo "✗ Health check failed - app did not become responsive"
  echo "App logs:"
  cat /tmp/app.log || true
  return 1
}

# Run healthcheck in warmup mode
if [ -n "${WARMUP:-}" ]; then
  healthcheck
fi

echo "Environment setup complete."
