import { createServer } from 'node:http';
import { pathToFileURL } from 'node:url';
import path from 'node:path';
import { ARTIFACT, verifyArtifact } from './retirement-artifact.mjs';

await verifyArtifact();
const worker = (await import(pathToFileURL(path.join(ARTIFACT, 'worker.mjs')).href)).default;
const server = createServer(async (request, response) => {
  request.resume();
  try {
    const result = worker.fetch(new Request('http://127.0.0.1:4337' + request.url, { method: request.method }));
    response.writeHead(result.status, Object.fromEntries(result.headers));
    response.end(Buffer.from(await result.arrayBuffer()));
  } catch {
    response.writeHead(500); response.end();
  }
});
server.listen(4337, '127.0.0.1', () => console.log('Retirement fixture listening on loopback.'));
process.on('SIGTERM', () => server.close());
