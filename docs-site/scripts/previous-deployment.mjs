import { readFile } from 'node:fs/promises';
import { pathToFileURL } from 'node:url';

const uuid = (value) => typeof value === 'string' && /^[a-f0-9]{8}(?:-[a-f0-9]{4}){3}-[a-f0-9]{12}$/.test(value);

// Locked Wrangler 4.128.0 emits an ascending-created_on deployment array.
// Select the latest deployment, never an arbitrary id or newest unused version.
export function previousVersion(deployments) {
  if (!Array.isArray(deployments) || deployments.length === 0 || deployments.length > 10
      || deployments.some((row) => !row || !uuid(row.id) || typeof row.created_on !== 'string'
        || !/^\d{4}-\d\d-\d\dT/.test(row.created_on) || !Number.isFinite(Date.parse(row.created_on)))) {
    throw new Error('previous_deployment_shape');
  }
  const ordered = [...deployments].sort((a, b) => Date.parse(b.created_on) - Date.parse(a.created_on));
  if (ordered.length > 1 && Date.parse(ordered[0].created_on) === Date.parse(ordered[1].created_on)) throw new Error('ambiguous_previous_deployment');
  const versions = ordered[0].versions;
  if (!Array.isArray(versions) || versions.length !== 1 || versions[0].percentage !== 100 || !uuid(versions[0].version_id)) {
    throw new Error('previous_deployment_requires_single_full_traffic_version');
  }
  return versions[0].version_id;
}

if (process.argv[1] && import.meta.url === pathToFileURL(process.argv[1]).href) {
  if (process.argv.length !== 3) throw new Error('previous_deployment_arguments');
  console.log(previousVersion(JSON.parse(await readFile(process.argv[2], 'utf8'))));
}
