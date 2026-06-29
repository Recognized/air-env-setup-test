#!/usr/bin/env bash
set -euo pipefail

cd /workspaces/air-env-setup-test

node --version
npm --version

npm install --prefer-offline

echo "Startup complete."
