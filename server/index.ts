import http from 'node:http';
import fs from 'node:fs';
import path from 'node:path';
import { fileURLToPath } from 'node:url';
import { reduce } from '../shared/reducer.ts';
import { makeSeed } from '../shared/seed.ts';
import type { Action, AppState, AssistantMessage } from '../shared/types.ts';
import { answer, aiStatus } from './ai.ts';

const here = path.dirname(fileURLToPath(import.meta.url));
const DATA = path.join(here, 'data');
const FILES = path.join(DATA, 'files');
const STATE_FILE = path.join(DATA, 'state.json');
const DIST = path.join(here, '..', 'web', 'dist');
const PUBLIC = path.join(here, '..', 'web', 'public');
const PORT = Number(process.env.PORT ?? 4000);

fs.mkdirSync(FILES, { recursive: true });

let state: AppState = (() => {
  try {
    return JSON.parse(fs.readFileSync(STATE_FILE, 'utf8')) as AppState;
  } catch {
    return makeSeed();
  }
})();

const clients = new Set<http.ServerResponse>();
const seen = new Map<string, number>();
function touch(req: http.IncomingMessage) {
  const ip = (req.headers['cf-connecting-ip'] as string | undefined) ?? req.socket.remoteAddress ?? '?';
  const ua = String(req.headers['user-agent'] ?? '');
  const app = ua.startsWith('FairShare') ? 'iPhone app' : /iPhone/.test(ua) ? 'iPhone Safari' : 'browser';
  const key = `${ip} · ${app}`;
  if (!seen.has(key) || Date.now() - (seen.get(key) ?? 0) > 30000) console.log(`${new Date().toLocaleTimeString()}  ✓ ${app} online  (${ip})`);
  seen.set(key, Date.now());
}
const recent = () => [...seen].filter(([, t]) => Date.now() - t < 10000).map(([k]) => k);

function persist() {
  fs.writeFile(STATE_FILE, JSON.stringify(state), () => {});
}

function broadcast() {
  const payload = `event: state\ndata: ${JSON.stringify(state)}\n\n`;
  for (const res of clients) res.write(payload);
}

function externalize(image: string | undefined): string | undefined {
  if (!image || !image.startsWith('data:')) return image;
  const m = image.match(/^data:(image\/(png|jpe?g|webp|heic)|application\/pdf);base64,(.+)$/);
  if (!m) return undefined;
  const ext = m[1] === 'application/pdf' ? 'pdf' : m[2] === 'jpeg' ? 'jpg' : m[2];
  const name = `${Date.now().toString(36)}${Math.random().toString(36).slice(2, 7)}.${ext}`;
  fs.writeFileSync(path.join(FILES, name), Buffer.from(m[3], 'base64'));
  return `/api/files/${name}`;
}

function apply(action: Action) {
  if (action.type === 'expense/submit') action.expense.image = externalize(action.expense.image);
  if (action.type === 'expense/document') action.image = externalize(action.image);
  if (action.type === 'demo/reset') {
    for (const f of fs.readdirSync(FILES)) fs.rmSync(path.join(FILES, f), { force: true });
  }
  const before = state.version;
  state = reduce(state, action);
  if (state.version <= before) state = { ...state, version: before + 1 };
  persist();
  broadcast();
}

const MIME: Record<string, string> = {
  '.html': 'text/html; charset=utf-8',
  '.js': 'text/javascript; charset=utf-8',
  '.css': 'text/css; charset=utf-8',
  '.svg': 'image/svg+xml',
  '.png': 'image/png',
  '.jpg': 'image/jpeg',
  '.jpeg': 'image/jpeg',
  '.webp': 'image/webp',
  '.pdf': 'application/pdf',
  '.json': 'application/json',
  '.ico': 'image/x-icon',
  '.woff2': 'font/woff2',
  '.wasm': 'application/wasm',
  '.gz': 'application/gzip',
  '.webmanifest': 'application/manifest+json',
};

function sendFile(res: http.ServerResponse, file: string) {
  fs.readFile(file, (err, buf) => {
    if (err) {
      res.writeHead(404).end('Not found');
      return;
    }
    res.writeHead(200, { 'Content-Type': MIME[path.extname(file).toLowerCase()] ?? 'application/octet-stream', 'Cache-Control': 'no-cache' });
    res.end(buf);
  });
}

function readBody(req: http.IncomingMessage, limit = 25 * 1024 * 1024): Promise<string> {
  return new Promise((resolve, reject) => {
    let size = 0;
    const chunks: Buffer[] = [];
    req.on('data', (c: Buffer) => {
      size += c.length;
      if (size > limit) {
        reject(new Error('Payload too large'));
        req.destroy();
        return;
      }
      chunks.push(c);
    });
    req.on('end', () => resolve(Buffer.concat(chunks).toString('utf8')));
    req.on('error', reject);
  });
}

const json = (res: http.ServerResponse, code: number, body: unknown) => {
  res.writeHead(code, { 'Content-Type': 'application/json' });
  res.end(JSON.stringify(body));
};

const today = () => new Date().toISOString().slice(0, 10);

const server = http.createServer(async (req, res) => {
  const url = new URL(req.url ?? '/', `http://${req.headers.host ?? 'localhost'}`);
  res.setHeader('Access-Control-Allow-Origin', '*');
  res.setHeader('Access-Control-Allow-Headers', 'Content-Type');
  res.setHeader('Access-Control-Allow-Methods', 'GET,POST,OPTIONS');
  if (req.method === 'OPTIONS') return void res.writeHead(204).end();

  try {
    if (url.pathname.startsWith('/api/') && url.pathname !== '/api/health') touch(req);
    if (url.pathname === '/api/health') return json(res, 200, { ok: true, version: state.version, ai: aiStatus(), clients: clients.size, devices: recent() });

    if (url.pathname === '/api/state' && req.method === 'GET') {
      const since = url.searchParams.get('since');
      if (since !== null && Number(since) === state.version) return void res.writeHead(204, { 'Cache-Control': 'no-store' }).end();
      res.setHeader('Cache-Control', 'no-store');
      return json(res, 200, state);
    }

    if (url.pathname === '/api/events') {
      res.writeHead(200, { 'Content-Type': 'text/event-stream', 'Cache-Control': 'no-cache', Connection: 'keep-alive', 'X-Accel-Buffering': 'no' });
      res.write(`retry: 1500\nevent: state\ndata: ${JSON.stringify(state)}\n\n`);
      clients.add(res);
      console.log(`${new Date().toLocaleTimeString()}  device connected (${clients.size} live)  from ${req.headers['cf-connecting-ip'] ?? req.socket.remoteAddress}`);
      const ping = setInterval(() => res.write(': ping\n\n'), 15000);
      req.on('close', () => {
        clearInterval(ping);
        clients.delete(res);
      });
      return;
    }

    if (url.pathname === '/api/action' && req.method === 'POST') {
      const { action } = JSON.parse(await readBody(req)) as { action: Action };
      const hasImage = action.type === 'expense/submit' && !!action.expense.image;
      apply(action);
      const who = req.headers['cf-connecting-ip'] ?? req.socket.remoteAddress;
      console.log(`${new Date().toLocaleTimeString()}  ${action.type}${hasImage ? ' (with photo)' : ''}  from ${who}  → v${state.version}`);
      return json(res, 200, { ok: true, version: state.version, state });
    }

    if (url.pathname === '/api/assistant' && req.method === 'POST') {
      const { orgId, messages } = JSON.parse(await readBody(req)) as { orgId: string; messages: AssistantMessage[] };
      if (!state.orgs.some((o) => o.id === orgId)) return json(res, 400, { error: 'Unknown organization' });
      return json(res, 200, await answer(state, orgId, messages, today()));
    }

    if (url.pathname.startsWith('/api/files/')) {
      const name = path.basename(url.pathname);
      return sendFile(res, path.join(FILES, name));
    }

    if (url.pathname.startsWith('/api/')) return json(res, 404, { error: 'Not found' });

    const rel = decodeURIComponent(url.pathname).replace(/^\/+/, '');
    for (const root of [DIST, PUBLIC]) {
      const file = path.join(root, rel);
      if (file.startsWith(root) && fs.existsSync(file) && fs.statSync(file).isFile()) return sendFile(res, file);
    }
    const index = path.join(DIST, 'index.html');
    if (fs.existsSync(index)) return sendFile(res, index);
    res.writeHead(200, { 'Content-Type': 'text/plain' }).end('FairShare API is running. Start the web app with `npm run dev`.');
  } catch (error) {
    console.error(error);
    json(res, 500, { error: (error as Error).message });
  }
});

server.listen(PORT, () => {
  const ai = aiStatus();
  console.log(`\n  FairShare sync server  →  http://localhost:${PORT}`);
  console.log(`  AI assistant           →  ${ai.engine === 'claude' ? 'Claude (claude-opus-5-5)' : `offline engine (${ai.reason})`}\n`);
});
