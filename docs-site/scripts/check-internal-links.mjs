#!/usr/bin/env node
/**
 * Validates every internal link against the routes the build actually
 * produced (N85-50 AC3).
 *
 * A broken internal link fails the build. External links are reported but do
 * not fail it, because a network check makes the pipeline depend on somebody
 * else's uptime; they are listed so a reviewer can see what the site points at.
 */
import { readdir, readFile } from 'node:fs/promises';
import { existsSync } from 'node:fs';
import path from 'node:path';
import process from 'node:process';

const root = path.resolve(import.meta.dirname, '..');
const dist = path.join(root, 'dist');

if (!existsSync(dist)) {
  console.error('dist/ is absent. Run "npm run build" before checking links.');
  process.exit(1);
}

async function* walk(dir) {
  for (const entry of await readdir(dir, { withFileTypes: true })) {
    const full = path.join(dir, entry.name);
    if (entry.isDirectory()) yield* walk(full);
    else if (entry.isFile()) yield full;
  }
}

/** Every path the build can serve, normalised without a trailing slash. */
const routes = new Set();
const htmlFiles = [];
for await (const file of walk(dist)) {
  const relative = '/' + path.relative(dist, file).split(path.sep).join('/');
  if (file.endsWith('.html')) {
    htmlFiles.push(file);
    routes.add(relative.replace(/\/index\.html$/, '').replace(/\.html$/, '') || '/');
  }
  routes.add(relative);
}
routes.add('/');

const broken = [];
const external = new Set();

const HREF = /href="([^"]+)"/g;

for (const file of htmlFiles) {
  const html = await readFile(file, 'utf8');
  const from = '/' + path.relative(dist, file).split(path.sep).join('/');
  let match;
  while ((match = HREF.exec(html)) !== null) {
    const href = match[1];

    if (/^(https?:)?\/\//.test(href)) {
      external.add(href.split('#')[0]);
      continue;
    }
    // Not a route: in-page anchors, mail, telephone and data URLs.
    if (href.startsWith('#') || /^(mailto|tel|data):/.test(href)) continue;
    if (!href.startsWith('/')) continue;

    const target = href.split('#')[0].split('?')[0].replace(/\/$/, '') || '/';
    if (!routes.has(target)) {
      broken.push({ from: from.replace(/\/index\.html$/, '/'), href });
    }
  }
}

console.log(`Checked ${htmlFiles.length} pages against ${routes.size} routes.`);
console.log(`External destinations referenced: ${external.size}`);
for (const url of [...external].sort()) {
  console.log(`  → ${url}`);
}

if (broken.length === 0) {
  console.log('\nInternal links: all resolve.');
  process.exit(0);
}

console.error(`\nInternal links: ${broken.length} broken.\n`);
for (const item of broken) {
  console.error(`  ${item.from}  →  ${item.href}`);
}
process.exit(1);
