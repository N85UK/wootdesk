# WootDesk Delivery Index

Document ID: `WOOT-INDEX-001`

Status: In review

Owner: N85 Dev

Last reviewed: 30 August 2026

## Current delivery position

Milestone 1 provides the complete connection and conversation-list vertical
slice. The maintainer has confirmed a live connection to a self-hosted Chatwoot
server. Automated release checks must still pass on the final commit.

The foundation is suitable for source review and signed TestFlight preparation.
It is not approved for a public App Store release. Conversation message history
and replies are the next product gate.

## Delivery documents

| Area | Source of truth |
|---|---|
| Product scope | `docs/PRODUCT.md` |
| Architecture and compatibility | `docs/ARCHITECTURE.md` |
| Milestones | `docs/ROADMAP.md` |
| App Store process | `docs/APP_STORE_SUBMISSION.md` |
| Listing copy | `docs/APP_STORE_METADATA.md` |
| Release decision | `docs/RELEASE_READINESS.md` |
| Requirement evidence | `docs/governance/REQUIREMENT_TRACEABILITY.md` |
| Delivery risks | `docs/governance/RISK_REGISTER.md` |
| Durable decisions | `docs/governance/DECISION_LOG.md` and `docs/decisions/` |
| Security and privacy | `SECURITY.md` and `PRIVACY.md` |
| Brand and icon | `docs/BRANDING.md` |

## Delivery gates

| Gate | Required evidence | Current state |
|---|---|---|
| G1 Repository foundation | Shared scheme, scripts, CI, documentation | Implemented |
| G2 Secure connection | Profile validation, Keychain token, profile persistence | Implemented and locally verified |
| G3 Conversation list | Real list, paging, filters, clear states | Implemented and locally verified |
| G4 Automated quality | macOS and iOS builds, unit tests, UI tests | Verified on 30 August 2026 |
| G5 Signed archives | iOS and macOS Organizer validation | Not started |
| G6 TestFlight | Physical-device and Mac acceptance | Not started |
| G7 Product completeness | Message history and replies | Blocked by Milestone 2 |
| G8 Public release | Explicit product, security, and release approval | No-go |

## Immediate priorities

1. Merge the reviewed foundation branch without secrets or personal signing data.
2. Implement Milestone 2 message history and reply workflows.
3. Prepare a dedicated review-only Chatwoot environment with invented data.
4. Validate signed iOS and macOS archives using the organisation team.
5. Complete TestFlight evidence before considering public submission.

Delivery status changes must cite a command result, App Store Connect record, or
named approval. A passing build does not imply release approval.
