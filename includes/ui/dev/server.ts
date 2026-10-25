import { watch } from 'node:fs';
import { realpath } from 'node:fs/promises';
import { dirname, extname, isAbsolute, relative, resolve, sep } from 'node:path';
import { fileURLToPath } from 'node:url';

const uiRoot = await realpath(resolve(dirname(fileURLToPath(import.meta.url)), '..'));
const clients = new Set<ReadableStreamDefaultController<Uint8Array>>();
const encoder = new TextEncoder();
const revision = `${Date.now()}`;
let reloadTimer: ReturnType<typeof setTimeout>;

function sendEvent(message: string) {
  for (const client of clients) client.enqueue(encoder.encode(message));
}

const watcher = watch(uiRoot, { recursive: true }, (eventType, filename) => {
  if (!filename || !['.html', '.css', '.js', '.json', '.svg', '.png', '.woff', '.woff2', '.ts'].includes(extname(filename))) return;
  clearTimeout(reloadTimer);
  reloadTimer = setTimeout(() => sendEvent('event: reload\ndata: changed\n\n'), 120);
});

const heartbeat = setInterval(() => sendEvent(': heartbeat\n\n'), 15000);

const server = Bun.serve({
  hostname: '127.0.0.1',
  port: 3000,
  idleTimeout: 0,
  async fetch(request) {
    const url = new URL(request.url);
    if (request.method !== 'GET' && request.method !== 'HEAD') return new Response('Method not allowed', { status: 405 });
    if (url.pathname === '/__dev/events') {
      let client: ReadableStreamDefaultController<Uint8Array>;
      const stream = new ReadableStream<Uint8Array>({
        start(controller) {
          client = controller;
          clients.add(controller);
          controller.enqueue(encoder.encode(`event: ready\ndata: ${revision}\n\n`));
        },
        cancel() { clients.delete(client); }
      });
      return new Response(stream, { headers: { 'Content-Type': 'text/event-stream', 'Cache-Control': 'no-cache' } });
    }
    try {
      const pathname = decodeURIComponent(url.pathname === '/' ? '/settings.html' : url.pathname);
      const target = await realpath(resolve(uiRoot, `.${pathname}`));
      const relativePath = relative(uiRoot, target);
      if (relativePath === '..' || relativePath.startsWith(`..${sep}`) || isAbsolute(relativePath)) return new Response('Not found', { status: 404 });
      const file = Bun.file(target);
      const headers = { 'Cache-Control': 'no-store' };
      if (target === resolve(uiRoot, 'settings.html')) {
        const html = (await file.text()).replace('<script src="app.js"></script>', '<script src="dev/fixtures.js"></script><script src="dev/browser.js"></script><script src="app.js"></script>');
        return new Response(request.method === 'HEAD' ? null : html, { headers: { ...headers, 'Content-Type': 'text/html; charset=utf-8' } });
      }
      return new Response(request.method === 'HEAD' ? null : file, { headers: { ...headers, 'Content-Type': file.type } });
    } catch {
      return new Response('Not found', { status: 404 });
    }
  }
});

console.log(`Settings UI: ${server.url}?page=plugin-Automations`);
console.log('Browser mock data only. Save a UI file to reload the page. Restart this command after server.ts changes.');

process.on('SIGINT', () => {
  watcher.close();
  clearInterval(heartbeat);
  clearTimeout(reloadTimer);
  server.stop(true);
  process.exit(0);
});
