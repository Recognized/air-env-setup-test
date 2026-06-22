const http = require('http');

const API_KEY = process.env.API_KEY;
const DATABASE_PASSWORD = process.env.DATABASE_PASSWORD;

if (!API_KEY || !DATABASE_PASSWORD) {
  console.error('Missing required secrets: API_KEY and DATABASE_PASSWORD must both be set.');
  process.exit(1);
}

const port = process.env.PORT || 3000;
http
  .createServer((req, res) => {
    res.writeHead(200, { 'Content-Type': 'text/plain' });
    res.end('ok\n');
  })
  .listen(port, () => console.log(`listening on ${port}`));
