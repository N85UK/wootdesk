/**
 * Serves the built site for the accessibility checks.
 *
 * `astro preview` is a persistent daemon: if one is already running it prints a
 * notice and exits, which makes it useless as a test fixture because the test
 * runner sees the process die and gives up. This serves dist/ directly, starts
 * clean every time, and stops when the runner stops it.
 */
import { createServer } from 'node:http';
import { readFile, stat } from 'node:fs/promises';
import path from 'node:path';
import { fileURLToPath } from 'node:url';

const root = path.join(path.dirname(fileURLToPath(import.meta.url)), '..', 'dist');
const port = Number(process.env.PORT ?? 4321);

const TYPES = {
  '.html': 'text/html; charset=utf-8',
  '.css': 'text/css; charset=utf-8',
  '.js': 'text/javascript; charset=utf-8',
  '.json': 'application/json; charset=utf-8',
  '.svg': 'image/svg+xml',
  '.png': 'image/png',
  '.jpg': 'image/jpeg',
  '.webp': 'image/webp',
  '.avif': 'image/avif',
  '.woff2': 'font/woff2',
  '.wasm': 'application/wasm',
  '.txt': 'text/plain; charset=utf-8',
  '.xml': 'application/xml; charset=utf-8',
};

async function resolve(urlPath) {
  const decoded = decodeURIComponent(urlPath.split('?')[0]);
  // Keep the resolved path inside dist, so a traversal cannot read the repo.
  const candidate = path.normalize(path.join(root, decoded));
  if (!candidate.startsWith(root)) return null;

  try {
    const info = await stat(candidate);
    if (info.isDirectory()) {
      const index = path.join(candidate, 'index.html');
      await stat(index);
      return index;
    }
    return candidate;
  } catch {
    return null;
  }
}

createServer(async (request, response) => {
  const file = await resolve(request.url ?? '/');
  if (!file) {
    response.writeHead(404, { 'content-type': 'text/plain; charset=utf-8' });
    response.end('Not found');
    return;
  }
  const body = await readFile(file);
  response.writeHead(200, {
    'content-type': TYPES[path.extname(file)] ?? 'application/octet-stream',
  });
  response.end(body);
}).listen(port, '127.0.0.1', () => {
  console.log(`Serving dist/ on http://127.0.0.1:${port}`);
});
