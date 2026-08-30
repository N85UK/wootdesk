# Delivery Risk Register

Document ID: `WOOT-RISK-001`

Owner: N85 Dev

Last reviewed: 30 August 2026

Probability and impact use a 1 to 5 scale. Score is probability multiplied by
impact. Scores support triage but do not replace owner judgement.

| ID | Risk | Probability | Impact | Score | Response | State |
|---|---|---:|---:|---:|---|---|
| RISK-001 | App Store Connect may not accept both platform archives from the current single multiplatform target because current Apple documents are inconsistent | 2 | 4 | 8 | Preflight both archives. Add thin distribution targets only if App Store Connect requires them | Open |
| RISK-002 | A public foundation release may disappoint users because message history and replies are absent | 4 | 4 | 16 | Keep public release blocked until Milestone 2 acceptance | Open |
| RISK-003 | App Review cannot validate the server-dependent workflow | 3 | 5 | 15 | Provide an isolated review server with invented data and stable private credentials | Open |
| RISK-004 | Privacy disclosures drift when telemetry, push, crash reporting, or AI is added | 3 | 5 | 15 | Review the policy, manifest, binary traffic, and App Store answers for every release | Open |
| RISK-005 | Self-hosted Chatwoot or reverse-proxy response differences break decoding or authentication | 3 | 4 | 12 | Retain tolerant DTO mapping, typed errors, fixtures, and compatibility tests | Reduced |
| RISK-006 | Product artwork or listing copy is mistaken for official Chatwoot branding | 2 | 5 | 10 | Use an original generic icon, independent-project notice, and final rights review | Reduced |
| RISK-007 | A personal development-team identifier or signing asset is committed | 2 | 4 | 8 | Keep automatic signing without `DEVELOPMENT_TEAM`; scan the final diff | Reduced |
| RISK-008 | Screenshots or review fixtures expose customer information or a live token | 2 | 5 | 10 | Use dedicated invented data and keep access only in private review fields | Open |

Review open risks before each TestFlight build and public release decision. Add
an owner and target date when a release candidate is scheduled.
