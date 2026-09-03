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
