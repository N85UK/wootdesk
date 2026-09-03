/**
 * Checks that external links in the built site still resolve.
 *
 * N85-50 AC3 asks for internal links to fail the build and external failures to
 * be reported "with an approved exception process for temporary or
 * access-controlled targets". Those are different obligations, so this treats
 * them differently:
 *
 *   - A 404 or 410 is the far end saying the page is not there. That fails.
 *   - A 429 or 408 is the far end saying "not so fast". A timeout, a connection
 *     error or a 5xx is it having a bad day. Those are reported and do not fail,
 *     because a documentation build should not break when somebody else's server
 *     is busy. The first draft of this check treated 429 as broken and reported
 *     nineteen good GitHub links as dead on its first real run.
 *   - A 401 or 403 is access control, which is the "access-controlled targets"
 *     case the requirement names. Reported, not failed.
 *   - Anything in link-exceptions.json is reported and never fails, with the
 *     reason and the date it was approved shown, so an exception cannot sit
 *     there unexamined forever.
 *
 * Rate limiting is real: hosts are contacted one at a time with a small delay.
 */
import { readdir, readFile, stat } from 'node:fs/promises';
import { existsSync } from 'node:fs';
import path from 'node:path';
import { fileURLToPath } from 'node:url';

const root = path.join(path.dirname(fileURLToPath(import.meta.url)), '..');
const dist = path.join(root, 'dist');
const exceptionsFile = path.join(root, 'link-exceptions.json');

if (!existsSync(dist)) {
  console.error('dist/ is absent. Run "npm run build" before checking links.');
  process.exit(1);
}

// The site's own origin is not an external target. Its pages appear here as
// canonical and og:url values, and a page added in this commit does not exist
// at that address until the deployment that follows. Checking them would fail
// the build for every new page, which is the opposite of useful. Internal
// routes are already covered by check-internal-links.mjs.
const ownOrigin = 'https://docs.n85.app';

const exceptions = existsSync(exceptionsFile)
  ? JSON.parse(await readFile(exceptionsFile, 'utf8'))
  : { exceptions: [] };

const excepted = new Map(exceptions.exceptions.map((item) => [item.url, item]));

async function* walk(directory) {
  for (const entry of await readdir(directory, { withFileTypes: true })) {
    const full = path.join(directory, entry.name);
    if (entry.isDirectory()) yield* walk(full);
    else if (entry.name.endsWith('.html')) yield full;
  }
}

const found = new Map();
for await (const file of walk(dist)) {
  const html = await readFile(file, 'utf8');
  const page = '/' + path.relative(dist, file).split(path.sep).join('/');
  for (const match of html.matchAll(/(?:href|src)="(https?:\/\/[^"]+)"/g)) {
    const url = match[1].replace(/&amp;/g, '&');
    if (url.startsWith(ownOrigin)) continue;
    if (!found.has(url)) found.set(url, new Set());
    found.get(url).add(page);
  }
}

const sleep = (ms) => new Promise((resolve) => setTimeout(resolve, ms));

const broken = [];
const flaky = [];
const skipped = [];
const lastSeen = new Map();
const sameHostCount = new Map();
for (const url of found.keys()) {
  const host = new URL(url).host;
  sameHostCount.set(host, (sameHostCount.get(host) ?? 0) + 1);
}

for (const [url, pages] of [...found].sort()) {
  if (excepted.has(url)) {
    skipped.push({ url, ...excepted.get(url) });
    continue;
  }
  let status = 0;
  let error = '';
  try {
    const controller = new AbortController();
    const timer = setTimeout(() => controller.abort(), 15_000);
    // Some hosts refuse HEAD, so fall back to a ranged GET rather than
    // recording a false failure.
    let response = await fetch(url, { method: 'HEAD', redirect: 'follow', signal: controller.signal });
    if (response.status === 405 || response.status === 403) {
      response = await fetch(url, {
        method: 'GET',
        redirect: 'follow',
        headers: { range: 'bytes=0-0' },
        signal: controller.signal,
      });
    }
    clearTimeout(timer);
    status = response.status;
  } catch (cause) {
    error = cause.name === 'AbortError' ? 'timed out' : cause.message;
  }

  const where = [...pages].slice(0, 3).join(', ');
  const transient = status === 429 || status === 408 || status >= 500;
  const accessControlled = status === 401 || status === 403;
  if (error || transient || accessControlled) {
    flaky.push({ url, detail: error || `HTTP ${status}`, where });
  } else if (status >= 400) {
    broken.push({ url, detail: `HTTP ${status}`, where });
  }
  // Politeness per host, not per link: seventeen of these point at GitHub, and
  // hammering one host is what earned the 429s in the first place.
  const host = new URL(url).host;
  lastSeen.set(host, Date.now());
  await sleep(sameHostCount.get(host) > 3 ? 900 : 300);
}

console.log(`External links: checked ${found.size - skipped.length}, ${skipped.length} excepted.`);

for (const item of skipped) {
  console.log(`  excepted  ${item.url}\n            ${item.reason} (approved ${item.approved})`);
}
for (const item of flaky) {
  console.log(`  ::warning::unreachable ${item.url} (${item.detail}) on ${item.where}`);
}
for (const item of broken) {
  console.log(`  BROKEN    ${item.url} (${item.detail}) on ${item.where}`);
}

if (broken.length > 0) {
  console.error(`\n${broken.length} external link(s) return a client error.`);
  console.error('Fix the link, or add it to link-exceptions.json with a reason and a date.');
  process.exit(1);
}
