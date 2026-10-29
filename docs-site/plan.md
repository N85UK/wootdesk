# WootDesk documentation retirement plan

## Purpose and authority

Prepare the existing public documentation site for the owner's instruction:
"Retire WootDesk; retain shared Chatwoot support." Scope is docs-site plus its
documentation, WootDesk App Review monitoring and TestFlight retirement gates.
Native app source,
stored profiles, messages, shared Chatwoot support and other sites are outside
this change. Local preparation only; no commit, push or deployment is performed.

Repository: N85UK/wootdesk, docs-site directory, owner branch main. Related
tracking: N85-47 documentation lifecycle. No remote issue state is asserted.
Reviewed the repository agent guide, documentation README, publication-boundary
decision, Worker configuration, deployment/availability/review workflows and
their scripts. This record adapts the project execution template using only
public-safe information.

## Architecture and acceptance criteria

- Retain the dedicated wootdesk-docs Worker and docs.n85.app custom domain.
  Keep workers_dev and preview_urls disabled. No shared build or route.
- Replace static-asset publication with a self-contained fetch Worker, without
  assets, bindings, environment access, outbound requests or product content.
- Every method and path returns 410 with a plain accessible retirement page.
  Only GET/HEAD /build-info.json returns 200 with exact commit, built and
  retired:true metadata. HEAD always has an empty body.
- All responses carry an explicit content type, no-store, noindex, nosniff and
  a restrictive CSP. Old documentation, downloads, search and asset URLs cannot
  fall back to old files or another site.
- Emit a separate verified retirement artifact. Preserve the legacy source and
  generated dist output, with a private ignored local baseline snapshot.
- CI tests, uploads and deploys that exact artifact only on push to main. It
  records an actual previous deployment and verifies full live retirement
  metadata and negative routes rather than trusting upload success.
- The six-hour probe expects retirement responses with strict TLS and no
  redirects. WootDesk-only App Review polling loses its automatic schedule.
  Shared Chatwoot monitoring and support remain unchanged.
- TestFlight loses its push trigger and every distribution job is disabled by
  an unconditional false expression, including manual dispatch. Ordinary app
  CI tests remain enabled. No App Store account action is performed.

## Runtime, dependencies and deployment

Existing Cloudflare Worker runtime; VPS/systemd/Docker decisions are not
applicable. Keep existing locked dependencies and existing deployment secret
names. No account, token, binding, DNS, route or permission is added. This
existing public repository and main-gated Worker CI are deliberate existing
publication boundaries, not a new repository or hosting decision.

Phases: preserve the baseline; implement the no-assets Worker and deterministic
artifact; adapt only the scoped workflows/probe; run offline Node/Python,
boundary, build/type/syntax and available local accessibility checks; review
the full scoped diff and hand off exact hashes. External checks, provider
actions, immutable commit and publication remain with the owner.

## Risk, rollback and stop conditions

Stop if retirement would require a shared route/build, new binding, broader
permissions, private material or weakening a publication guard. Retain all old
code/output and failed evidence. A rollback uses the exact previous dedicated
Worker deployment version and validates its actual metadata; it requires an
owner decision because it reopens retired content. Local rollback reverses only
this slice, never unrelated native or execution-document changes.

Status: local preparation complete, owner publication review pending. Offline
contracts passed 86 Node cases and seven Python cases; eight cached-browser
accessibility cases passed. The separate artifact verifies and is explicitly
marked sourceDirty:true because the retirement source is not committed yet.
The publication gate refuses it. Type checking reports zero errors/warnings and
three existing hints. YAML, source privacy, boundary and diff checks passed.
The old generated output and seven unrelated source/document hashes match the
private baseline. No provider, App Store, Git publication or external HTTP call.
Autonomy: authorised local implementation/testing. Provider publication and
native-app distribution remain separate from these local documentation checks.

## Coordinator publication decision, 29 October 2026

The owner explicitly retired WootDesk while retaining shared Chatwoot support. Root has reviewed the dedicated Worker, exact artifact verification, rollback selection, native distribution gate and source preservation. Root authorises this scoped website release through the existing main-branch documentation workflow. The retained local dirty artifact is not a release: the clean CI checkout must build and verify the new immutable commit before deployment. This grants no App Store action, account change, credential expansion, DNS change or VPS lifecycle operation. Live retirement remains pending exact commit, negative-route and strict-TLS readback.
