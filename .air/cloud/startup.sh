#!/usr/bin/env bash
set -euo pipefail

# Verify required secrets are present
if [ -z "${API_KEY:-}" ]; then
  echo "ERROR: API_KEY is not set" >&2
  exit 1
fi

if [ -z "${DATABASE_PASSWORD:-}" ]; then
  echo "ERROR: DATABASE_PASSWORD is not set" >&2
  exit 1
fi

# Install Node.js dependencies
npm install

echo "Environment setup complete."
