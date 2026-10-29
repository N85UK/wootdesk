export const RETIREMENT_PAGE = `<!doctype html>
<html lang="en-GB">
<head>
<meta charset="utf-8">
<meta name="viewport" content="width=device-width, initial-scale=1">
<meta name="robots" content="noindex, nofollow, noarchive">
<title>WootDesk has been retired</title>
</head>
<body>
<main>
<h1>WootDesk has been retired.</h1>
<p>WootDesk documentation and downloads are no longer available here.</p>
<p>Existing shared Chatwoot support is unaffected.</p>
</main>
</body>
</html>
`;

export const SECURITY_HEADERS = Object.freeze({
  'cache-control': 'no-store, no-transform',
  'x-robots-tag': 'noindex, nofollow, noarchive',
  'x-content-type-options': 'nosniff',
  'content-security-policy': "default-src 'none'; base-uri 'none'; form-action 'none'; frame-ancestors 'none'",
  'referrer-policy': 'no-referrer',
  'x-frame-options': 'DENY',
});

export function validateBuildInfo(value) {
  if (!value || typeof value !== 'object' || Array.isArray(value)
      || Object.keys(value).sort().join(',') !== 'built,commit,retired'
      || typeof value.commit !== 'string' || !/^[a-f0-9]{40}$/.test(value.commit) || value.retired !== true
      || typeof value.built !== 'string' || !/^\d{4}-\d\d-\d\dT\d\d:\d\d:\d\d\.\d{3}Z$/.test(value.built)
      || !Number.isFinite(Date.parse(value.built)) || new Date(value.built).toISOString() !== value.built) {
    throw new Error('invalid_retirement_metadata');
  }
  return value;
}

export function createRetirementWorker(value) {
  const metadata = JSON.stringify(validateBuildInfo(value)) + '\n';
  return Object.freeze({
    fetch(request) {
      const head = request.method === 'HEAD';
      const metadataRequest = (request.method === 'GET' || head)
        && new URL(request.url).pathname === '/build-info.json';
      return new Response(head ? null : metadataRequest ? metadata : RETIREMENT_PAGE, {
        status: metadataRequest ? 200 : 410,
        headers: {
          ...SECURITY_HEADERS,
          'content-type': metadataRequest ? 'application/json; charset=utf-8' : 'text/html; charset=utf-8',
        },
      });
    },
  });
}
