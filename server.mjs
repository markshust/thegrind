// THE GRIND — persistence server.
// Owns grind.db (real SQLite, on disk) and serves the page. The browser syncs
// to /api/state on every change, so your progress lives outside the browser and
// survives any cache clear, reinstall, or new machine. No human direction needed.
//
// Uses Node's BUILT-IN SQLite (node:sqlite) — no npm install, no native build.
// Requires Node 22.5+ (run with --experimental-sqlite on 22.x; stable on 24+).
//
//   node --experimental-sqlite server.mjs
//
import { createServer } from 'node:http';
import { readFile, copyFile } from 'node:fs/promises';
import { fileURLToPath } from 'node:url';
import { dirname, join } from 'node:path';
import { DatabaseSync } from 'node:sqlite';

const dir = dirname(fileURLToPath(import.meta.url));
const PORT = process.env.PORT || 47417;

const db = new DatabaseSync(join(dir, 'grind.db'));
db.exec('CREATE TABLE IF NOT EXISTS state (id INTEGER PRIMARY KEY CHECK (id = 1), data TEXT NOT NULL)');

// node:sqlite auto-finalizes long-lived prepared statements (crashes with
// "statement has been finalized"), so prepare fresh per call — it's cheap.
const readState = () => db.prepare('SELECT data FROM state WHERE id = 1').get();
const writeState = (data) =>
  db.prepare('INSERT INTO state (id, data) VALUES (1, ?) ON CONFLICT(id) DO UPDATE SET data = excluded.data').run(data);

createServer(async (req, res) => {
  if (req.url === '/api/state' && req.method === 'GET') {
    const row = readState();
    res.writeHead(200, { 'content-type': 'application/json' });
    return res.end(row ? row.data : 'null');
  }
  if (req.url === '/api/backup' && req.method === 'POST') {
    // snapshot grind.db → grind.db.bak before a reset, so a wipe is recoverable
    try { await copyFile(join(dir, 'grind.db'), join(dir, 'grind.db.bak')); } catch {}
    res.writeHead(204).end();
    return;
  }
  if (req.url === '/api/state' && req.method === 'PUT') {
    let body = '';
    req.on('data', (c) => (body += c));
    req.on('end', () => {
      try {
        JSON.parse(body);            // validate it's JSON before persisting
        writeState(body);
        res.writeHead(204).end();
      } catch {
        res.writeHead(400).end('bad json');
      }
    });
    return;
  }
  // everything else: serve the app
  try {
    const html = await readFile(join(dir, 'index.html'));
    res.writeHead(200, { 'content-type': 'text/html; charset=utf-8' }).end(html);
  } catch {
    res.writeHead(404).end('not found');
  }
}).listen(PORT, '127.0.0.1', () => {
  console.log(`\n  THE GRIND is live → http://localhost:${PORT}`);
  console.log(`  Progress persists in ${join(dir, 'grind.db')} (SQLite)\n`);
});
