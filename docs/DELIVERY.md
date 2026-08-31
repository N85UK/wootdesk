# WootDesk Delivery Index

Document ID: `WOOT-INDEX-001`

Status: In review

Owner: N85 Dev

Last reviewed: 31 August 2026

## Current delivery position

Milestone 1 provides the complete connection and conversation-list vertical
slice. The Milestone 2 source now provides paginated message history, public
replies, private notes, safe inline message presentation, and file attachment
upload and display boundaries. The maintainer has confirmed a live connection
to a self-hosted Chatwoot server, but the new message workflow has not yet
completed dedicated invented-data server or TestFlight acceptance.

Build 4 source adds native notification permission, local verification, and
APNs registration state. It does not include the required authenticated push
provider, so remote Chatwoot new-message delivery is not active.

The source and local build 3 archives are suitable for release review. The iOS
App Store package exports locally. It is not approved for a public App Store
release, and neither build 3 candidate has been uploaded. The uploaded build 2
predates the Milestone 2 source changes.

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
| Live Chatwoot compatibility | `docs/CHATWOOT_COMPATIBILITY.md` |
| Physical TestFlight acceptance | `docs/TESTFLIGHT_TEST_PLAN.md` |
| macOS UI-test host setup | `docs/MACOS_UI_TESTING.md` |
| Push notification design and activation | `docs/PUSH_NOTIFICATIONS.md` |

## Delivery gates

| Gate | Required evidence | Current state |
|---|---|---|
| G1 Repository foundation | Shared scheme, scripts, CI, documentation | Implemented |
| G2 Secure connection | Profile validation, Keychain token, profile persistence | Implemented and locally verified |
| G3 Conversation list | Real list, paging, filters, clear states | Implemented and locally verified |
| G4 Automated quality | macOS and iOS builds, unit tests, UI tests | Builds and 93 unit tests pass; 3 iPhone and 3 iPad UI journeys pass; macOS host configuration gate documented |
| G5 Signed archives | iOS and macOS Organizer validation | Build 3 iOS and universal macOS archives pass local checks; iOS package export passes |
| G6 TestFlight | Physical-device and Mac acceptance | Not started |
| G7 Product completeness | Message history, replies, private notes, and attachments | Source implementation complete; live acceptance pending |
| G8 Public release | Explicit product, security, and release approval | No-go |
| G9 Remote notifications | Push provider, push-capable signing, and profile-safe physical-device delivery | Client foundation implemented; provider not implemented |

## Immediate priorities

1. Prepare a dedicated review-only Chatwoot environment with invented data.
2. Run the opt-in live compatibility matrix for history, replies, private notes,
   and attachments.
3. Implement and review the authenticated Chatwoot-to-APNs provider without
   sending Chatwoot personal access tokens to it.
4. Enable Push Notifications on the App ID and regenerate both platform
   profiles before creating a signed build 4 archive.
5. Complete physical-device, remote-delivery, and Mac acceptance before
   considering public submission.

Delivery status changes must cite a command result, App Store Connect record, or
named approval. A passing build does not imply release approval.
