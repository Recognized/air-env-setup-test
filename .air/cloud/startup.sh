#!/usr/bin/env bash
set -euo pipefail

cd "$(git rev-parse --show-toplevel)"

echo "Node: $(node --version)"
echo "npm: $(npm --version)"

if [[ -z "${API_KEY:-}" ]]; then
  echo "API_KEY is required for this repository." >&2
  exit 1
fi

if [[ -z "${DATABASE_PASSWORD:-}" ]]; then
  echo "DATABASE_PASSWORD is required for this repository." >&2
  exit 1
fi

if [[ -f package-lock.json || -f npm-shrinkwrap.json ]]; then
  npm ci
elif [[ -f package.json ]] && node -e "const p=require('./package.json'); process.exit(p.dependencies || p.devDependencies ? 0 : 1)"; then
  npm install
else
  echo "No npm dependencies to install."
fi

node --check app.js
