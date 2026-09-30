#!/bin/bash
set -e

echo "Starting environment setup..."

# Determine startup mode
if [ "${AIR_STARTUP_MODE:-}" = warmup ]; then
  WARMUP=1
else
  WARMUP=
fi

# Install dependencies
echo "Installing npm dependencies..."
npm install

# Create .env file with required secrets
echo "Setting up environment variables..."
cat > .env <<EOF
API_KEY=${API_KEY}
DATABASE_PASSWORD=${DATABASE_PASSWORD}
PORT=${PORT:-3000}
EOF

# Start the app in the background
echo "Starting application..."
nohup npm start >/tmp/app.log 2>&1 &
APP_PID=$!
echo "Application started with PID $APP_PID"

# Health check function - tests if the app is ready
healthcheck() {
  local max_attempts=30
  local attempt=0
  local port=${PORT:-3000}

  echo "Waiting for application to be ready on port $port..."

  while [ $attempt -lt $max_attempts ]; do
    if curl -sf http://localhost:$port/ > /dev/null 2>&1; then
      echo "✓ Application is ready"
      return 0
    fi

    attempt=$((attempt + 1))
    echo "  Attempt $attempt/$max_attempts - waiting..."
    sleep 2
  done

  echo "✗ Application failed to start within timeout"
  echo "Recent logs:"
  tail -20 /tmp/app.log
  return 1
}

# In warmup mode, wait for the app to be ready before returning
if [ -n "${WARMUP:-}" ]; then
  healthcheck
fi

echo "Setup complete"
