# WootDesk documentation retirement

This directory prepares the retirement response for the dedicated
`wootdesk-docs` Worker at `https://docs.n85.app`. Publication and actual live
readback are separate owner-controlled steps. Shared Chatwoot support is
unaffected.

The retirement Worker has no assets, bindings, environment access or outbound
requests. Every path and method returns **410 Gone** with an accessible plain
retirement page. Only `GET` and `HEAD /build-info.json` return 200 with exact
`commit`, `built` and `retired: true` metadata. Every HEAD response has no body.
Responses include no-store, noindex, nosniff and a restrictive CSP.

The dedicated Worker name/custom domain remain unchanged. `workers_dev` and
`preview_urls` stay disabled. No other site's route, build or index is shared.
The original documentation sources and old `dist/` output remain retained;
none are part of the retirement artifact or served as a fallback.

## Local preparation

Use Node.js 22 or later and the existing locked dependencies. Run from this
folder. Do not install dependencies or contact a provider merely to inspect or
test this source if the local dependencies are already present.

```sh
npm run check
npm run test:retirement
npm run build
npm run verify:boundary
npm run verify:retirement
npm run verify:a11y:retirement
```

The build creates a fresh `retirement-artifact/` with exactly three files:
`worker.mjs`, `build-info.json` and `artifact-manifest.json`. It never writes
`dist/`, `public/` or the documentation source. Existing output is refused
rather than overwritten. Retain it and use a fresh checkout for another release
build. The manifest records the exact Worker and metadata hashes.

A local working tree with edits can be tested using
`npm run build -- --allow-dirty`. That explicit candidate has `sourceDirty:true`
in its manifest and is refused by the deployment verification gate. It is not a
release from the recorded commit. CI builds from a clean immutable checkout and
requires its exact commit again before publication.

Retained Astro commands remain available for historical source checks and local
archive work: `npm run build:legacy`, `npm run verify:links`,
`npm run verify:external` and `npm run verify:a11y`. They are not the production
retirement build. Preserve old output before any legacy rebuild. Never publish
it through the retirement configuration.

## CI and publication

Pull requests verify the retirement artifact. Only a push to `main` may deploy,
using the existing production environment and existing deployment secret names.
The deployment job downloads and rechecks the exact uploaded artifact. Wrangler
uses its self-contained module with `--no-bundle`, without an assets fallback.
Missing credentials, unknown rollback metadata or failed verification fail the
job instead of claiming a publication.

Before deploying, CI reads the actual latest deployment of the dedicated Worker.
Only a single full-traffic version is an automatic rollback target; ambiguous or
weighted deployment state requires owner review. The release summary records
that exact previous version, the new version and artifact manifest hash. Raw
provider metadata is not printed.

After publication, strict TLS probes require retirement responses at the root,
old support/search/download/asset and negative paths, and compare the complete
live metadata to the verified artifact. Redirects, old 200 content, missing
security headers and mismatched metadata fail. The same contract is checked
every six hours. Probe output contains fixed diagnostics and timings, never
response bodies or credentials.

WootDesk-specific automatic App Review polling has been removed. Its historical
manual diagnostic remains available; no shared Chatwoot monitor is modified.
The TestFlight workflow has no push trigger and its distribution job is
unconditionally disabled, including manual dispatch. Ordinary app CI tests
remain enabled. No App Store account or existing binary was changed here.

## Recovery and limits

Retain the old source, generated output, previous Worker version and every failed
check. A rollback reopens retired content and needs an owner decision. Use the
recorded exact version with the dedicated Worker's rollback command, then verify
its actual metadata and route independently. Never substitute another project's
Worker or introduce a shared route to restore availability.

Local tests do not prove a provider deployment, DNS/TLS state, installed client,
App Review change or shared-support outcome. See [plan](plan.md),
[runbook](runbook.md) and [change record](change-log.md) for this preparation.
