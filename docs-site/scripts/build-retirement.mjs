import { execFileSync } from 'node:child_process';
import { buildArtifact, ROOT } from './retirement-artifact.mjs';

const args = process.argv.slice(2);
if (args.some((arg) => arg !== '--allow-dirty')) throw new Error('unknown_build_argument');
const head = execFileSync('git', ['rev-parse', 'HEAD'], { cwd: ROOT, encoding: 'utf8' }).trim();
if (process.env.GITHUB_SHA && process.env.GITHUB_SHA !== head) throw new Error('checkout_commit_mismatch');
const sourceDirty = execFileSync('git', ['status', '--porcelain'], { cwd: ROOT, encoding: 'utf8' }).trim() !== '';
if (sourceDirty && !args.includes('--allow-dirty')) throw new Error('dirty_candidate_requires_explicit_local_flag');
const manifest = await buildArtifact({ commit: head, built: new Date().toISOString(), sourceDirty });
console.log(JSON.stringify({ ...manifest.metadata, sourceDirty, files: manifest.files }));
