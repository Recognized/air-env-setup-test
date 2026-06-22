#!/usr/bin/env bash
set -euo pipefail

echo "Verifying required secrets are present..."

missing=0
for var in API_KEY DATABASE_PASSWORD; do
  if [ -z "${!var:-}" ]; then
    echo "ERROR: required secret '$var' is not set."
    missing=1
  else
    echo "OK: $var is set."
  fi
done

if [ "$missing" -ne 0 ]; then
  echo "Environment setup incomplete: fill the required secrets and re-run."
  exit 1
fi

echo "All required secrets present. Environment is ready."
