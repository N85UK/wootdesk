# ADR 0007: Public and Private Documentation Publication Boundary

## Context

N85 needs documentation for more than one project. WootDesk's documentation
must be public. Documentation for other N85 projects, and internal operational
material, must not be.

The tempting arrangement is one Starlight site with some pages marked private,
or two sites sharing a build. Both are wrong, and the reason is that "private"
would then be a rendering decision taken late, after the private text has
already been read into the same build. A shared build leaks through more
surfaces than most people enumerate: generated HTML, the Pagefind index,
sitemaps, RSS feeds, source maps, build logs, and preview deployments that
usually have weaker access control than production.

## Decision

Three independently built and deployed sites, with no shared build step, no
shared search index and no shared Worker route.

| Site | Address | Audience | Source |
| --- | --- | --- | --- |
| App home | `n85.app` | Public | Its own repository, N85-63 |
| WootDesk documentation | `docs.n85.app` | Public | `docs-site/` in `N85UK/wootdesk` |
| N85 internal documentation | `docs.n85.dev` | Cloudflare Access only | A separate private repository |

**The public WootDesk site lives in the WootDesk repository.** A change to
user-visible behaviour and the documentation of that behaviour then travel in
the same pull request and are traceable to the same commit.

**The private site lives in its own repository.** Not a private directory in a
public repository, and not a branch. The separation is at the repository
boundary so that cloning the public repository cannot obtain private text, and
so that a misconfigured build cannot reach it.

**No redirect, alias or shared route connects them.** `docs.n85.dev` is never
aliased to `docs.n85.app`, and no public page links to `docs.n85.dev` except
where a link is explicitly marked as restricted internal documentation and
approved for that audience.

**Private previews inherit production access.** A preview deployment of the
private site sits behind the same Cloudflare Access policy as its production
site. An unauthenticated preview URL is treated as a leak, not a convenience.

## Content classification

A page belongs on the **public** site only when all of these hold:

1. It concerns WootDesk.
2. It is suitable for a reader with no relationship to N85.
3. It contains no other N85 project's material.
4. It contains no customer data, credential, private hostname, internal IP
   range or infrastructure detail.
5. Every example uses invented data or a reserved example domain.

If any one fails, it belongs in the private repository. There is no
"public with a caveat" state.

## Enforcement

Classification is a rule, so it is checked by a program rather than by
remembering.

`docs-site/scripts/check-content-boundary.mjs` scans both the source tree and
the built output for the private hostname, internal-only markers, private IP
ranges, credential-shaped assignments, private key blocks and cloud access
keys. It runs in CI and blocks deployment. It scans `dist/` as well as `src/`
because a leak can arrive through a component, a config value or a generated
index rather than through a Markdown page.

Draft release notes are excluded structurally rather than by convention: they
live in a collection that is not automatically routed, and every route,
listing, sitemap entry and search record derives from a single filtered
function. A draft therefore has no route to leak through. CI asserts this
directly against the built output.

## Consequences

- Three builds and three deployments to operate, rather than one.
- Shared presentation between the sites must be duplicated or extracted into a
  package. Duplication is accepted for now; the sites are small and the cost of
  a shared build is the thing this decision exists to avoid.
- A contributor must decide which repository a page belongs in before writing
  it. The checklist in `CONTRIBUTING.md` exists to make that decision quick.
- The private site is not built or deployed from this repository at all, so
  nothing here can publish it by accident.
