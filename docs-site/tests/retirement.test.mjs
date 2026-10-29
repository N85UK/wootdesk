import test from 'node:test';
import assert from 'node:assert/strict';
import { mkdir, mkdtemp, readFile, writeFile, symlink } from 'node:fs/promises';
import path from 'node:path';
import { pathToFileURL } from 'node:url';
import { createRetirementWorker, validateBuildInfo, RETIREMENT_PAGE, SECURITY_HEADERS } from '../retirement/worker.mjs';
import { ROOT, buildArtifact, verifyArtifact, verifyWorkerConfig, validateWorkerConfig, sha256 } from '../scripts/retirement-artifact.mjs';
import { previousVersion } from '../scripts/previous-deployment.mjs';
import YAML from 'yaml';

const metadata = { commit: 'a'.repeat(40), built: '2026-10-29T08:00:00.000Z', retired: true };
const worker = createRetirementWorker(metadata);
const request = (method, pathname) => ({ method, url: 'https://docs.example.invalid' + pathname });

test('every old route and method is gone, with no asset or search fallback', async (t) => {
  for (const pathname of ['/', '/help/support/', '/pagefind/pagefind.js', '/downloads/WootDesk.dmg', '/_astro/legacy.js', '/releases/1.0.0/', '/build-info.json/', '/unknown']) {
    for (const method of ['GET', 'HEAD', 'POST', 'PUT', 'PATCH', 'DELETE', 'OPTIONS', 'TRACE', 'CONNECT']) {
      await t.test(method + ' ' + pathname, async () => {
        const response = worker.fetch(request(method, pathname));
        assert.equal(response.status, 410);
        for (const [name, value] of Object.entries(SECURITY_HEADERS)) assert.equal(response.headers.get(name), value);
        assert.equal(response.headers.get('content-type'), 'text/html; charset=utf-8');
        assert.equal(response.headers.get('location'), null);
        assert.equal(await response.text(), method === 'HEAD' ? '' : RETIREMENT_PAGE);
      });
    }
  }
});

test('only GET and HEAD on exact metadata path return 200', async () => {
  assert.deepEqual(await worker.fetch(request('GET', '/build-info.json')).json(), metadata);
  const head = worker.fetch(request('HEAD', '/build-info.json'));
  assert.equal(head.status, 200); assert.equal(head.body, null); assert.equal(await head.text(), '');
  assert.equal(head.headers.get('content-type'), 'application/json; charset=utf-8');
  for (const method of ['POST', 'PUT', 'PATCH', 'DELETE', 'OPTIONS']) assert.equal(worker.fetch(request(method, '/build-info.json')).status, 410);
  for (const pathname of ['/BUILD-INFO.JSON', '/build-info.json.old', '/%62uild-info.json']) assert.equal(worker.fetch(request('GET', pathname)).status, 410);
});

test('Worker ignores bindings and makes no outbound call', async () => {
  const original = globalThis.fetch;
  globalThis.fetch = () => { throw new Error('outbound_forbidden'); };
  try {
    const denied = new Proxy({}, { get() { throw new Error('binding_access_forbidden'); } });
    assert.equal(worker.fetch(request('GET', '/'), denied, denied).status, 410);
    assert.deepEqual(await worker.fetch(request('GET', '/build-info.json'), denied, denied).json(), metadata);
  } finally { globalThis.fetch = original; }
});

test('metadata rejects malformed, extra and falsely retired records', () => {
  for (const value of [null, [], {}, { ...metadata, retired: false }, { ...metadata, retired: 1 },
    { ...metadata, commit: ['a'.repeat(40)] }, { ...metadata, commit: 'bad' }, { ...metadata, extra: true },
    { ...metadata, built: '2026-02-31T08:00:00.000Z' }, { ...metadata, built: 'yesterday' }]) assert.throws(() => validateBuildInfo(value));
});

test('page is semantic, inert and agrees with the independent probe hash', async () => {
  assert.match(RETIREMENT_PAGE, /<html lang="en-GB">/); assert.match(RETIREMENT_PAGE, /<main>/);
  assert.match(RETIREMENT_PAGE, /<h1>WootDesk has been retired\.<\/h1>/);
  assert.doesNotMatch(RETIREMENT_PAGE, /<(?:script|style|link|img|iframe|form|a)\b/i);
  const source = await readFile(path.join(ROOT, '../script/check_docs_availability.py'), 'utf8');
  assert.ok(source.includes("RETIREMENT_BODY_SHA256 = '" + sha256(RETIREMENT_PAGE) + "'"));
});

async function output() {
  await mkdir(path.join(ROOT, '.retirement-evidence'), { recursive: true, mode: 0o700 });
  const parent = await mkdtemp(path.join(ROOT, '.retirement-evidence/contract-'));
  return path.join(parent, 'artifact');
}

test('separate artifact verifies exact bytes and executes as the real Worker module', async () => {
  const outDir = await output(); await buildArtifact({ outDir, ...metadata });
  const proof = await verifyArtifact({ outDir, expectedCommit: metadata.commit, requireClean: true });
  assert.deepEqual(proof.metadata, metadata);
  const deployed = (await import(pathToFileURL(path.join(outDir, 'worker.mjs')).href)).default;
  assert.equal(deployed.fetch(request('GET', '/pagefind/pagefind.js')).status, 410);
  assert.deepEqual(await deployed.fetch(request('GET', '/build-info.json')).json(), metadata);
  await assert.rejects(buildArtifact({ outDir, ...metadata }), /EEXIST/);
  await assert.rejects(verifyArtifact({ outDir, expectedCommit: 'b'.repeat(40) }), /artifact_commit/);
});

test('changed code, extra assets, symlinks and dirty publication fail artifact admission', async (t) => {
  for (const kind of ['changed', 'extra', 'link', 'dirty']) {
    await t.test(kind, async () => {
      const outDir = await output(); await buildArtifact({ outDir, ...metadata, sourceDirty: kind === 'dirty' });
      if (kind === 'changed') await writeFile(path.join(outDir, 'worker.mjs'), 'export default {};');
      if (kind === 'extra') await writeFile(path.join(outDir, 'old-page.html'), 'old public fixture');
      if (kind === 'link') await symlink('build-info.json', path.join(outDir, 'asset-link'));
      await assert.rejects(verifyArtifact({ outDir, requireClean: true }));
    });
  }
});

test('dedicated no-assets config refuses bindings, other routes and previews', async () => {
  const config = await verifyWorkerConfig();
  for (const changed of [{ ...config, assets: { directory: './dist' } }, { ...config, vars: { fixture: 'public' } },
    { ...config, workers_dev: true }, { ...config, preview_urls: true }, { ...config, routes: [{ pattern: 'example.invalid', custom_domain: true }] },
    { ...config, main: './dist/worker.mjs' }]) assert.throws(() => validateWorkerConfig(changed));
});

test('rollback identifies latest active full-traffic version, never an unused version', () => {
  const row = (digit, time, percentage = 100) => ({ id: digit.repeat(8) + '-1111-4111-8111-111111111111', created_on: time,
    versions: [{ version_id: digit.repeat(8) + '-2222-4222-8222-222222222222', percentage }] });
  const first = row('1', '2026-10-28T00:00:00.000Z'), last = row('2', '2026-10-29T00:00:00.000Z');
  assert.equal(previousVersion([last, first]), last.versions[0].version_id);
  for (const invalid of [[], {}, [{ id: last.id }], [row('3', last.created_on, 50)], [last, { ...first, created_on: last.created_on }]]) assert.throws(() => previousVersion(invalid));
});

test('retirement gates every native distribution job while retaining normal CI', async () => {
  const workflow = async (name) => YAML.parse(await readFile(path.join(ROOT, '../.github/workflows', name), 'utf8'));
  const delivery = await workflow('testflight.yml');
  assert.deepEqual(Object.keys(delivery.on), ['workflow_dispatch']);
  assert.ok(Object.keys(delivery.jobs).length > 0);
  for (const job of Object.values(delivery.jobs)) assert.equal(job.if, '${{ false }}');
  const review = await workflow('review-environment.yml');
  assert.equal(review.on.schedule, undefined);
  const docs = await workflow('docs.yml');
  assert.equal(docs.jobs.deploy.if, "github.event_name == 'push' && github.ref == 'refs/heads/main'");
  const availability = await workflow('docs-availability.yml');
  assert.equal(availability.on.schedule[0].cron, '0 */6 * * *');
  const ci = await workflow('ci.yml');
  assert.deepEqual(ci.on.push.branches, ['main']);
  assert.ok(ci.jobs['build-and-test']);
  assert.notEqual(ci.jobs['build-and-test'].if, '${{ false }}');
});

test('retirement responses forbid intermediary transformations without relaxing byte checks', async () => {
  for (const pathname of ['/', '/help/support/', '/build-info.json']) {
    for (const method of ['GET', 'HEAD']) {
      const response = worker.fetch(request(method, pathname));
      assert.equal(response.headers.get('cache-control'), 'no-store, no-transform');
      if (method === 'GET' && pathname !== '/build-info.json') assert.equal(sha256(await response.text()), sha256(RETIREMENT_PAGE));
    }
  }
});
