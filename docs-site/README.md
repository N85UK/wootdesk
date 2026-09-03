# WootDesk Public Documentation

The public WootDesk documentation, published at <https://docs.n85.app>.

This directory is an [Astro Starlight](https://starlight.astro.build) site. It
builds to static files: no server runtime, no database, no product credential,
and no request to a Chatwoot server at build time.

## Publication boundary

This site carries **WootDesk documentation only**.

Documentation for any other N85 project, and any internal operational material,
belongs in the separate private repository published at `docs.n85.dev`. The two
never share a repository, a build, a search index or a route. See
[`docs/decisions/0007-documentation-publication-boundary.md`](../docs/decisions/0007-documentation-publication-boundary.md).

## Requirements

- Node.js 22 or later.
- npm. The `package-lock.json` is committed and dependencies are pinned to
  exact versions, so `npm ci` reproduces the same build.

## Commands

Run these from `docs-site/`.

| Command | What it does |
| --- | --- |
| `npm ci` | Install exactly the locked dependencies |
| `npm run dev` | Local preview with hot reload at `http://localhost:4321` |
| `npm run build` | Production build into `dist/` |
| `npm run preview` | Serve the built `dist/` as it will be published |
| `npm run check` | Type-check the site |
| `npm run verify` | Content boundary and internal link checks |

The full sequence CI runs is:

```bash
npm ci && npm run check && npm run build && npm run verify
```

## Adding a page

1. Create a Markdown or MDX file under `src/content/docs/`. The path becomes
   the route: `src/content/docs/guides/triage.md` serves `/guides/triage`.
2. Give it front matter with at least `title` and `description`. The
   description is used for search results and social previews, so write a real
   sentence rather than repeating the title.
3. Add it to the sidebar in `astro.config.mjs`. A page absent from the sidebar
   is still routed and still indexed, but nobody will find it by browsing.
4. Run `npm run build && npm run verify`.

## Adding a release note

Release notes are **not** ordinary docs pages. They live in
`src/content/releases/` and are routed explicitly by `src/pages/releases/`.

1. Create `src/content/releases/<version>.md`.
2. Fill in the front matter. The schema in `src/content.config.ts` is enforced
   at build time, so a missing or malformed field fails the build.
3. Set `status`:
   - `draft` is never built. Use it while the release is being prepared.
   - `testflight` is public, and states the build reached testers only.
   - `released` is public, and means generally available. Do not use it for a
     build that has not actually shipped.
4. Quote any list item containing a colon, or YAML will parse it as a mapping.

A `draft` note produces no route, no sitemap entry and no search record. CI
asserts this against the built output rather than trusting the filter.

### Accuracy

Every claim in a release note must be traceable to a Git tag, a pull request, a
Jira issue or recorded release evidence. Planned work is not described as
released, and a TestFlight build is not described as available.

## Safe examples

Public pages must use invented data and reserved domains:

```text
https://help.example.com
agent@example.com
```

Never a real access token, a real customer record, a production hostname that
is not already public, or a private IP range. `npm run verify` checks for
several of these, but it is a backstop, not a substitute for reading what you
wrote.

## Structure

```
docs-site/
├── astro.config.mjs          Site identity, sidebar, integrations
├── src/
│   ├── content.config.ts     Docs and release collection schemas
│   ├── content/
│   │   ├── docs/             Routed documentation pages
│   │   └── releases/         Release notes, routed explicitly
│   ├── pages/releases/       Release index, changelog, per-version routes
│   ├── components/           Footer and release rendering
│   ├── lib/releases.ts       The single filtered source of published releases
│   └── assets/               Logo
├── public/                   Files copied verbatim, including the favicon
└── scripts/                  Boundary and link checks run by CI
```

## Deployment

The site is served from a dedicated Cloudflare Worker configured in
`wrangler.jsonc`. Dedicated is deliberate: the private documentation at
`docs.n85.dev` is a separate Worker with its own build and search index, so no
shared route or index can serve private text from this hostname.

Deployment is automatic. A push to `main` that touches `docs-site/` runs the
checks, and the `deploy` job publishes the artefact those checks passed
against, rather than rebuilding. Nothing is deployed from a pull request.

### One-time setup, completed 3 September 2026

Both repository secrets are set, so deployment is automatic. The token is
scoped to exactly the three permissions below and nothing else; the account's
global key was used once to mint it and is not stored in CI.

| Secret | Value |
| --- | --- |
| `CLOUDFLARE_API_TOKEN` | Token named "wootdesk-docs deploy (docs.n85.app)" |
| `CLOUDFLARE_ACCOUNT_ID` | The account that owns the `n85.app` zone |

To re-create the token if it is ever revoked:

| Secret | Value |
| --- | --- |
| `CLOUDFLARE_API_TOKEN` | An API token scoped as below |
| `CLOUDFLARE_ACCOUNT_ID` | The Cloudflare account that owns the `n85.app` zone |

The token needs three permissions, and no more:

* **Account**, Workers Scripts, Edit. Publishes the Worker.
* **Zone**, Workers Routes, Edit, on `n85.app`. Attaches the custom domain.
* **Zone**, DNS, Edit, on `n85.app`. Creates the `docs.n85.app` record.

Cloudflare provisions and renews the certificate for a custom domain.

It does **not** redirect HTTP to HTTPS by itself. `always_use_https` is off on
the `n85.app` zone, and a Worker has no origin to issue the redirect, so plain
HTTP served the site with a 200 on first deployment. A single redirect rule
scoped to `docs.n85.app` now returns 301 to HTTPS, preserving the path and
query. It is scoped to this hostname rather than enabling the zone-wide
setting, so the behaviour of other `n85.app` hosts is unchanged.

### What the deployment proves

`wrangler deploy` exiting zero means Cloudflare accepted the upload. It does
not mean visitors receive the new pages. The workflow therefore stamps the
commit into `build-info.json` before building, and after deploying fetches
`https://docs.n85.app/build-info.json` and fails unless the live site returns
that commit. A deployment that silently changed nothing fails the job.

### Deploying by hand

Only for recovery. Normal changes go through `main`.

```bash
cd docs-site
npm ci
npm run build
npm run verify
CLOUDFLARE_API_TOKEN=... CLOUDFLARE_ACCOUNT_ID=... npx wrangler deploy
```

### Rolling back

Every deployment records the version it replaced, and the run summary prints
the command with that version already in it. To roll back:

```bash
cd docs-site
npx wrangler rollback <version id> --message "why"
```

Assets belong to a Worker version, so a rollback restores the pages as well as
the code. Confirm it took effect by reading the commit back from the live site
rather than trusting the command:

```bash
curl -s https://docs.n85.app/build-info.json
```

Roll forward the same way, naming the version you came from.

**Exercised on 3 September 2026** for N85-47 AC10, not merely written down.
Rolled `docs.n85.app` from version `20860954` back to `2534e22f`, confirmed the
live site served the earlier commit with the home page, a guide page, the HTTP
to HTTPS redirect and all security headers intact, then rolled forward and
confirmed the current commit was serving again. `n85.app` was unaffected
throughout, which is the independence the criterion asks for: the two sites are
separate Workers with separate deployments.

The drill used a temporary Cloudflare token scoped to Workers Scripts alone,
revoked immediately afterwards, so it did not depend on or expose the token CI
uses.

### The workers.dev hostname is disabled

`workers_dev` and `preview_urls` are both off. A workers.dev address would be
an unmanaged second copy of the public site, outside the canonical address,
the sitemap and the certificate, which is the situation N85-47 AC4 exists to
prevent.
