#!/usr/bin/env bash
set -euo pipefail

port="${PORT:-3000}"

node - "$port" <<'NODE'
const http = require('http');
const port = Number(process.argv[2]);
const deadline = Date.now() + 15000;

function probe() {
  const request = http.get({ host: '127.0.0.1', port, path: '/', timeout: 1000 }, response => {
    let body = '';
    response.setEncoding('utf8');
    response.on('data', chunk => { body += chunk; });
    response.on('end', () => {
      if (response.statusCode === 200 && body === 'ok\n') process.exit(0);
      retry(`unexpected response: HTTP ${response.statusCode}, body ${JSON.stringify(body)}`);
    });
  });
  request.on('timeout', () => request.destroy(new Error('request timed out')));
  request.on('error', error => retry(error.message));
}

function retry(reason) {
  if (Date.now() >= deadline) {
    console.error(`health check failed on port ${port}: ${reason}`);
    process.exit(1);
  }
  setTimeout(probe, 250);
}

probe();
NODE
