// Zero-dependency static server for the web build.
// Usage: node tools/serve-web.mjs [port]   → http://localhost:8060
// Listens on all interfaces so a phone on the same Wi-Fi can open
// http://<this-pc-ip>:8060 (the printed LAN addresses).
import http from 'node:http';
import fs from 'node:fs';
import path from 'node:path';
import os from 'node:os';
import { fileURLToPath } from 'node:url';

const root = path.resolve(path.dirname(fileURLToPath(import.meta.url)), '../builds/web');
const port = Number(process.argv[2] || 8060);
const types = {
  '.html': 'text/html', '.js': 'application/javascript', '.wasm': 'application/wasm',
  '.pck': 'application/octet-stream', '.png': 'image/png', '.json': 'application/json',
  '.svg': 'image/svg+xml', '.ico': 'image/x-icon',
};

http.createServer((req, res) => {
  const url = decodeURIComponent(new URL(req.url, 'http://x').pathname);
  let file = path.join(root, url === '/' ? 'index.html' : url);
  if (!file.startsWith(root) || !fs.existsSync(file) || fs.statSync(file).isDirectory()) {
    res.writeHead(404).end('not found');
    return;
  }
  res.writeHead(200, {
    'Content-Type': types[path.extname(file)] || 'application/octet-stream',
    'Cache-Control': 'no-cache',
  });
  fs.createReadStream(file).pipe(res);
}).listen(port, '0.0.0.0', () => {
  console.log(`Serving ${root}`);
  console.log(`  http://localhost:${port}`);
  for (const nets of Object.values(os.networkInterfaces()))
    for (const n of nets) if (n.family === 'IPv4' && !n.internal) console.log(`  http://${n.address}:${port}  (phone on same Wi-Fi)`);
});
