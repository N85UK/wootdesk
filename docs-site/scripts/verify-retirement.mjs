import { verifyArtifact, verifyWorkerConfig } from './retirement-artifact.mjs';

const args = process.argv.slice(2);
const clean = args.includes('--require-clean');
const commitIndex = args.indexOf('--expect-commit');
const expectedCommit = commitIndex < 0 ? undefined : args[commitIndex + 1];
const allowed = clean ? ['--require-clean'] : [];
if (commitIndex >= 0) allowed.push('--expect-commit', expectedCommit);
if (JSON.stringify(args.toSorted()) !== JSON.stringify(allowed.toSorted())
    || (commitIndex >= 0 && !/^[a-f0-9]{40}$/.test(expectedCommit ?? ''))) throw new Error('verify_arguments');
await verifyWorkerConfig();
console.log(JSON.stringify(await verifyArtifact({ expectedCommit, requireClean: clean })));
