#!/usr/bin/env bash
set -euo pipefail

port="${PORT:-3000}"
deadline=$((SECONDS + 20))

while (( SECONDS < deadline )); do
  if response="$(node -e '
    const http = require("http");
    const request = http.get({host: "127.0.0.1", port: process.argv[1], path: "/", timeout: 1000}, response => {
      let body = "";
      response.setEncoding("utf8");
      response.on("data", chunk => body += chunk);
      response.on("end", () => {
        if (response.statusCode === 200) process.stdout.write(body);
        else process.exit(1);
      });
    });
    request.on("timeout", () => request.destroy());
    request.on("error", () => process.exit(1));
  ' "$port" 2>/dev/null)" && [[ "$response" == "ok" ]]; then
    echo "air-env-setup-test is healthy on port $port"
    exit 0
  fi
  sleep 0.5
done

echo "air-env-setup-test did not become healthy on port $port" >&2
exit 1
