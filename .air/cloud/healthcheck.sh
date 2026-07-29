#!/usr/bin/env bash
set -euo pipefail

repo_root="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
port="${PORT:-3000}"
deadline=$((SECONDS + 30))

while (( SECONDS < deadline )); do
  if response="$(node -e '
    const http = require("http");
    const port = Number(process.argv[1]);
    const req = http.get({host: "127.0.0.1", port, path: "/", timeout: 1000}, res => {
      let body = "";
      res.setEncoding("utf8");
      res.on("data", chunk => body += chunk);
      res.on("end", () => {
        if (res.statusCode === 200 && body === "ok\n") process.stdout.write(body);
        else process.exit(1);
      });
    });
    req.on("timeout", () => req.destroy());
    req.on("error", () => process.exit(1));
  ' "$port" 2>/dev/null)" && [ "$response" = "ok" ]; then
    echo "air-env-setup-test is healthy on port $port"
    exit 0
  fi
  sleep 1
done

echo "Health check timed out waiting for port $port" >&2
if [ -f "$repo_root/.air/cloud/run/server.log" ]; then
  tail -n 50 "$repo_root/.air/cloud/run/server.log" >&2
fi
exit 1
