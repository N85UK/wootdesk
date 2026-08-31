# Delivery Risk Register

Document ID: `WOOT-RISK-001`

Owner: N85 Dev

Last reviewed: 31 August 2026

Probability and impact use a 1 to 5 scale. Score is probability multiplied by
impact. Scores support triage but do not replace owner judgement.

| ID | Risk | Probability | Impact | Score | Response | State |
|---|---|---:|---:|---:|---|---|
| RISK-001 | App Store Connect may not accept the macOS archive from the current single multiplatform target because current Apple documents are inconsistent | 2 | 4 | 8 | Build 3 is a valid universal archive and now exports as a signed App Store installer with the matching profile. Upload only with approval. Add thin distribution targets only if App Store Connect rejects the shared target | Reduced, upload proof pending |
| RISK-002 | Message history and replies may fail against a supported self-hosted response variant or in real agent use | 3 | 4 | 12 | Keep public release blocked until dedicated-server and TestFlight Milestone 2 acceptance | Reduced |
| RISK-003 | App Review cannot validate the server-dependent workflow | 3 | 5 | 15 | Provide an isolated review server with invented data and stable private credentials | Open |
| RISK-004 | Privacy disclosures drift when telemetry, push, crash reporting, or AI is added | 3 | 5 | 15 | Review the policy, manifest, binary traffic, and App Store answers for every release | Open |
| RISK-005 | Self-hosted Chatwoot or reverse-proxy response differences break decoding or authentication | 3 | 4 | 12 | Retain tolerant DTO mapping, typed errors, fixtures, and compatibility tests | Reduced |
| RISK-006 | Product artwork or listing copy is mistaken for official Chatwoot branding | 2 | 5 | 10 | Use an original generic icon, independent-project notice, and final rights review | Reduced |
| RISK-007 | A personal development-team identifier or signing asset is committed | 2 | 4 | 8 | Keep automatic signing without `DEVELOPMENT_TEAM`; scan the final diff | Reduced |
| RISK-008 | Screenshots or review fixtures expose customer information or a live token | 2 | 5 | 10 | Use dedicated invented data and keep access only in private review fields | Open |
| RISK-009 | App Store Connect build state and the repository release ledger drift apart | 2 | 3 | 6 | Record the build number, processing state, compliance state, and tester exposure after every release session | Open |
| RISK-010 | A received attachment URL leaks data or opens an unsafe destination | 2 | 5 | 10 | Accept only HTTPS outside debug localhost, show metadata without auto-fetch, require an explicit host confirmation, and never send the Chatwoot token to the attachment URL | Reduced |
| RISK-011 | macOS UI tests time out before execution on hosts requiring Automation Mode authentication | 1 | 3 | 3 | Fail fast, document Apple's one-time administrator command, keep the setting limited to controlled development or CI Macs, and never bypass TCC or System Integrity Protection | Mitigated on this host; recheck after macOS or Xcode updates |
| RISK-012 | A push provider routes a notification to the wrong profile, account, environment, user, or device | 3 | 5 | 15 | Use authenticated per-profile enrolment, opaque payload identifiers, mandatory route secret, optional verified HMAC adapter, idempotency, token rotation and deletion, and cross-profile physical-device acceptance. Replace or explicitly approve the current account-wide recipient policy before deployment | Open, source controls implemented, recipient policy and live proof pending |
| RISK-013 | The app presents Apple registration as working Chatwoot delivery without a compatible provider | 3 | 4 | 12 | Keep separate permission, Apple registration, and Chatwoot delivery states; never submit the APNs token to Chatwoot's FCM endpoint; block release claims until a real invented-data event arrives on a physical device | Reduced in client, delivery remains blocked |

Review open risks before each TestFlight build and public release decision. Add
an owner and target date when a release candidate is scheduled.
