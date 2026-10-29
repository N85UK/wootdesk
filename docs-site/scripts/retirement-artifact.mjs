import { createHash } from 'node:crypto';
import { readFile, readdir, lstat, mkdir, writeFile } from 'node:fs/promises';
import path from 'node:path';
import { validateBuildInfo } from '../retirement/worker.mjs';

export const ROOT = path.resolve(import.meta.dirname, '..');
export const ARTIFACT = path.join(ROOT, 'retirement-artifact');
export const sha256 = (bytes) => createHash('sha256').update(bytes).digest('hex');
const json = (value) => JSON.stringify(value, null, 2) + '\n';

export async function renderWorker(metadata) {
  validateBuildInfo(metadata);
  const source = await readFile(path.join(ROOT, 'retirement/worker.mjs'), 'utf8');
  return source + '\nexport default createRetirementWorker(Object.freeze(' + JSON.stringify(metadata) + '));\n';
}

export async function buildArtifact({ outDir = ARTIFACT, commit, built, sourceDirty = false }) {
  outDir = path.resolve(outDir);
  const evidence = path.join(ROOT, '.retirement-evidence') + path.sep;
  if (outDir !== ARTIFACT && !outDir.startsWith(evidence)) throw new Error('artifact_output_scope');
  const metadata = validateBuildInfo({ commit, built, retired: true });
  if (typeof sourceDirty !== 'boolean') throw new Error('artifact_source_state');
  const worker = await renderWorker(metadata);
  const info = JSON.stringify(metadata) + '\n';
  const manifest = {
    schema: 'wootdesk-docs-retirement/v1', metadata, sourceDirty,
    files: { 'worker.mjs': sha256(worker), 'build-info.json': sha256(info) },
  };
  await mkdir(outDir, { mode: 0o700 });
  for (const [name, value] of Object.entries({ 'worker.mjs': worker, 'build-info.json': info, 'artifact-manifest.json': json(manifest) })) {
    await writeFile(path.join(outDir, name), value, { flag: 'wx', mode: 0o600 });
  }
  return manifest;
}

export async function verifyArtifact({ outDir = ARTIFACT, expectedCommit, requireClean = false } = {}) {
  const directory = await lstat(outDir);
  if (!directory.isDirectory() || directory.isSymbolicLink()) throw new Error('artifact_directory');
  const names = (await readdir(outDir)).sort();
  if (names.join(',') !== 'artifact-manifest.json,build-info.json,worker.mjs') throw new Error('artifact_file_set');
  const files = {};
  for (const name of names) {
    const filename = path.join(outDir, name);
    const info = await lstat(filename);
    if (!info.isFile() || info.isSymbolicLink() || info.nlink !== 1 || info.size > 64 * 1024) throw new Error('artifact_regular_file');
    files[name] = await readFile(filename, 'utf8');
  }
  const manifest = JSON.parse(files['artifact-manifest.json']);
  if (files['artifact-manifest.json'] !== json(manifest)
      || Object.keys(manifest).sort().join(',') !== 'files,metadata,schema,sourceDirty'
      || manifest.schema !== 'wootdesk-docs-retirement/v1' || typeof manifest.sourceDirty !== 'boolean'
      || (requireClean && manifest.sourceDirty)) throw new Error('artifact_manifest');
  const metadata = validateBuildInfo(manifest.metadata);
  if (expectedCommit !== undefined && metadata.commit !== expectedCommit) throw new Error('artifact_commit');
  if (files['build-info.json'] !== JSON.stringify(metadata) + '\n'
      || files['worker.mjs'] !== await renderWorker(metadata)
      || Object.keys(manifest.files).sort().join(',') !== 'build-info.json,worker.mjs'
      || !Object.entries(manifest.files).every(([name, hash]) => sha256(files[name]) === hash)) throw new Error('artifact_bytes');
  return { metadata, manifestSha256: sha256(files['artifact-manifest.json']), workerSha256: manifest.files['worker.mjs'], sourceDirty: manifest.sourceDirty };
}

export function validateWorkerConfig(config) {
  const expected = {
    $schema: 'node_modules/wrangler/config-schema.json', name: 'wootdesk-docs', compatibility_date: '2026-09-03',
    main: './retirement-artifact/worker.mjs', workers_dev: false, preview_urls: false,
    routes: [{ pattern: 'docs.n85.app', custom_domain: true }], observability: { enabled: true },
  };
  if (JSON.stringify(config) !== JSON.stringify(expected)) throw new Error('dedicated_worker_config');
  return config;
}

export async function verifyWorkerConfig() {
  return validateWorkerConfig(JSON.parse(await readFile(path.join(ROOT, 'wrangler.jsonc'), 'utf8')));
}
