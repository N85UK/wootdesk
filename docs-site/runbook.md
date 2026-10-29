# WootDesk documentation retirement runbook

## Scope and recovery checkpoint

29 October 2026. Local preparation in docs-site, N85UK/wootdesk, main branch.
Related tracking: N85-47; no issue mutation. Existing Cloudflare Worker remains
wootdesk-docs on docs.n85.app. No native application or shared Chatwoot action.
The owner's coordinator reports the public site serving commit
9da89eede76509315f8d38c501a402dedb567d3f; this worker has not fetched it.

Preserve src, public, the old generated dist tree and the dedicated-route
boundary. Retain a private ignored local baseline of the files being changed
and old generated output before implementation. Preserve every unrelated dirty
file. No credentials or real account data are read, copied or logged.

## Intended release

Build a separate retirement-artifact containing only a self-contained Worker,
exact build metadata and a hash manifest. Wrangler main points to that Worker
and has no assets entry, binding or fallback. The Worker has no outbound calls
or environment access. All paths/methods return 410 except GET/HEAD
/build-info.json, whose exact commit/built/retired:true metadata returns 200.
HEAD has no body. Apply no-store/no-transform/noindex/nosniff and restrictive CSP throughout.

Existing CI remains the deployment mechanism: verify and upload one artifact,
then download and reverify those bytes in the push-main-only deployment job.
Missing credentials, an unknown previous active deployment or a failed actual
retirement readback fails the job. Never rebuild in the deploy job or use an old
asset directory as fallback. Existing deployment secret names are unchanged.

## Verification and operations

Local checks cover direct Worker semantics, unsafe/old routes and methods,
artifact tampering, strict metadata, probe negatives, existing public/private
boundary checks, syntax/types/build, and cached-browser accessibility where
available. Local fixtures use reserved example hosts and no genuine accounts.
Do not run external HTTP, provider-backed Wrangler commands, dependency
installation, commit, push or deployment in this preparation step.

The scheduled documentation probe still runs every six hours. It checks 410
retirement and exact valid metadata, rejects redirects/TLS failures and old
search/download successes, and never logs response content. WootDesk-only App
Review automatic polling is disabled; shared support monitoring is untouched.
The separate TestFlight workflow no longer has a push trigger and its delivery
job has an unconditional retired-product false condition, so manual dispatch
cannot sign or upload either. Ordinary non-distribution CI is unchanged. The
historical workflow was privately retained before this authorised narrow gate.

## Rollback and handoff

Record the actual dedicated Worker's active deployment/version before release.
Unknown or weighted rollback targets require owner review before publication.
Retain the validated artifact/hash and provider deployment identifiers. Owner
may restore the exact previous version only after deciding to reopen the old
content, then independently verify its metadata and dedicated route.

Autonomy: local implementation/testing. External provider access: not performed.
Runtime: existing Cloudflare Worker, no VPS service or Docker change. No DNS,
credential, retention or access-policy change. Next safe action is owner source
review, immutable commit and reviewed publication, followed by actual strict
retirement readback.

## Local preparation result

The no-assets Worker, separate artifact builder/verifier, strict retirement
probe and scoped workflows are implemented. The dedicated route and disabled
preview endpoints remain exact. No shared support monitor was edited. The
native delivery push trigger is removed and its only job is unconditionally
false; a YAML-backed regression protects this and ordinary CI test availability.

Commands run from docs-site:

```sh
npm run check
npm run test:retirement
npm run build -- --allow-dirty
npm run verify:boundary
npm run verify:retirement
npm run verify:a11y:retirement
```

Final results: 86 Node cases, seven Python cases and eight Chromium accessibility
cases passed, without skips. Accessibility covered mobile/desktop, light/dark,
root/old-support routes, semantic headings, keyboard behaviour, overflow and axe.
All fixture requests were loopback only. Type checking passed with zero
errors/warnings and three pre-existing hints. Workflow YAML and deployment gates
parsed and passed. The existing tracked-file public-repository check passed;
the same rules also passed across all new and changed scoped files. Content
boundary checks scanned legacy source/public/dist and the new source/artifact.

Output: retirement-artifact, exactly three files. Candidate metadata commit is
adb68b67e149b6641b282d87018ac6eba27a058e, built 2026-10-29T08:09:01.565Z.
Its manifest is explicitly sourceDirty:true. This is a tested local candidate,
not a release from that commit; clean publication verification refuses it.
Manifest SHA256: 03b0239847ed32500974f47eb9dbf46a904463f379cc987ceb4e1899a7676ebb.
Worker SHA256: 18cb73dd7cb637d39e1fdee12333da935bf486ca38843edfa92e494a0e7d5417.

Old dist has all 96 entries and 1615893 bytes of regular files unchanged. A
private ignored archive and original scoped source copies remain retained.
Seven unrelated native source/root-document hashes matched the baseline.
The unrelated Xcode Cloud directory was not edited. No file was deleted.

Not run: dependency installation, external-link/availability HTTP, provider
Wrangler commands, App Store/API/account operations, native app tests or release,
commit, push and deployment. Existing dependencies and cached browsers sufficed.
Cloudflare edge, current TLS/route behaviour and actual publication require root
review and independent live readback after a clean committed CI build. No source
or local-browser result is relabelled as that provider proof.

## Coordinator publication decision, 29 October 2026

The owner explicitly retired WootDesk while retaining shared Chatwoot support. Root has reviewed the dedicated Worker, exact artifact verification, rollback selection, native distribution gate and source preservation. Root authorises this scoped website release through the existing main-branch documentation workflow. The retained local dirty artifact is not a release: the clean CI checkout must build and verify the new immutable commit before deployment. This grants no App Store action, account change, credential expansion, DNS change or VPS lifecycle operation. Live retirement remains pending exact commit, negative-route and strict-TLS readback.
