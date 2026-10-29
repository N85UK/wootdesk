# WootDesk documentation change record

## 2026-10-29 - Prepare documentation retirement

Agent: documentation retirement worker. Related tracking: N85-47.
Scope: docs-site and WootDesk-specific documentation/review monitoring only.
Authority: owner requested WootDesk retirement while retaining shared Chatwoot.
Autonomy: local implementation/testing. External systems touched: none.
Runtime: unchanged dedicated Cloudflare Worker, with a new retirement artifact.
No Git publication, provider, DNS, credentials, native app or support change.

Plan: return a restrictive 410 retirement page for all old content, preserve a
narrow exact build-info exception, eliminate asset fallback, verify one artifact
through main-only CI, adapt availability probes and stop automatic WootDesk App
Review polling. Preserve old source/output and unrelated work. No new binding,
account, dependency or permission. Rollback requires the exact previous Worker
version and owner approval to reopen retired content. Validation and release
status remain pending until recorded after the local checks.

Local result: implemented the separate Worker/artifact path, exact artifact and
deployment-version validation, strict retirement probes and scoped workflow
gates. TestFlight no longer has a push trigger and all its distribution jobs are
unconditionally disabled, including manual dispatch. Ordinary CI and shared
Chatwoot support/monitoring are retained. Native source and data are unchanged.

Validation: 86 Node, seven Python and eight local-browser accessibility cases
passed. Build, artifact/source boundary, privacy, YAML and diff checks passed.
Type check: zero errors/warnings, three existing hints. Legacy dist and seven
unrelated file hashes match the private baseline. The artifact manifest records
sourceDirty:true, so the clean deployment gate refuses this local candidate.
No dependencies, account, DNS, provider, credentials, Git publication or live
service state changed. See runbook for exact commands, hashes and unrun gates.

Root review, 29 October 2026: the public repository now leads with the retirement notice and retains the historical feature and setup descriptions. The existing deployed 4.19.1 review-image pin remains the unchanged parent commit. Four unrelated native API safety edits, three root execution documents and the Xcode Cloud directory remain outside this website publication. The TestFlight job is unconditionally closed before this push; ordinary CI remains enabled.

29 October 2026, exact-response follow-up: the first clean CI deployment reached the expected retirement statuses, headers and metadata, but its HTML body hash failed while independent strict OS-curl requests matched the exact447-byte source. The failure remains unresolved evidence. Add no-transform to the existing no-store policy and require the stronger header in the probe. Keep the exact body hash, TLS, redirect, status and metadata checks. Body mismatches now emit only lengths, hashes and fixed script classifications, never HTML, provider identifiers or credential material. This is a narrow response-code change; no Cloudflare account setting, rule, DNS entry or access boundary changes. Rebuild from the new clean immutable commit and require actual CI and independent public readback.
