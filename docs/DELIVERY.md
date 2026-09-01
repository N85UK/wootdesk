# WootDesk Delivery Index

Document ID: `WOOT-INDEX-001`

Status: In review

Owner: N85 Dev

Last reviewed: 1 September 2026

## Current delivery position

Milestone 1 provides the complete connection and conversation-list vertical
slice. The Milestone 2 source now provides paginated message history, public
replies, private notes, safe inline message presentation, and file attachment
upload and display boundaries. The maintainer has confirmed a live connection
to a self-hosted Chatwoot server, but the new message workflow has not yet
completed dedicated invented-data server or TestFlight acceptance.

iPad now presents the same three adjacent areas as the Mac, through a shared
workspace sidebar and a `NavigationSplitView` that collapses on its own when the
window becomes too narrow. iPhone keeps its tab layout. The conversation status
filter becomes a menu at accessibility text sizes rather than clipping a
segmented control.

Conversation triage is now implemented in source: status, snooze with a future
return time, priority, agent and team assignment, and labels. Every triage
change is confirmed by reading the conversation back from Chatwoot, so WootDesk
never displays a value it has only requested. Label changes read the current
server set immediately before writing, because Chatwoot replaces rather than
merges the set. Notification routing now opens the identified conversation even
when it lies outside the loaded page or is hidden by a search or status filter,
and it reports an unavailable conversation rather than substituting another.
None of this has completed invented-data server acceptance.

Build 4 source adds the native notification client, secure device enrolment,
and the self-hostable authenticated WootDesk Push Gateway. Remote Chatwoot
new-message delivery is not active because the Apple capability, refreshed
profiles, gateway deployment, recipient-policy approval, and physical-device
acceptance remain open.

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
| Push gateway deployment and API contract | `Gateway/README.md` |

## Delivery gates

| Gate | Required evidence | Current state |
|---|---|---|
| G1 Repository foundation | Shared scheme, scripts, CI, documentation | Implemented |
| G2 Secure connection | Profile validation, Keychain token, profile persistence | Implemented and locally verified |
| G3 Conversation list | Real list, paging, filters, clear states | Implemented and locally verified |
| G4 Automated quality | macOS and iOS builds, unit tests, UI tests | The current source passes macOS and iOS Simulator builds, 183 Swift tests in 18 suites, 18 Node gateway tests, and the 3 macOS UI tests including the conversation history and reply journey; the three opt-in live compatibility tests are skipped by design. The recorded iPhone and iPad UI journeys have not been re-run on hardware since the conversation actions and the iPad split layout were added |
| G5 Signed archives | iOS and macOS Organizer validation | Build 3 iOS and universal macOS archives pass local checks; iOS package export passes |
| G6 TestFlight | Physical-device and Mac acceptance | Not started |
| G7 Product completeness | Message history, replies, private notes, attachments, and conversation triage | Source implementation complete; live acceptance pending |
| G8 Public release | Explicit product, security, and release approval | No-go |
| G9 Remote notifications | Push provider, push-capable signing, and profile-safe physical-device delivery | Client and gateway source implemented; capability, deployment, recipient policy, and physical acceptance pending |

## Immediate priorities

1. Prepare a dedicated review-only Chatwoot environment with invented data.
2. Run the opt-in live compatibility matrix for history, replies, private notes,
   attachments, availability, and triage.
3. Review and deploy the implemented Chatwoot-to-APNs gateway with approved
   Apple credentials, host secret storage, proxy-log redaction, and a recipient
   policy suitable for the deployment.
4. Enable Push Notifications on the App ID and regenerate both platform
   profiles before creating a signed build 4 archive.
5. Re-run the iPhone and iPad UI journeys on hardware against the current
   source, which now includes the conversation action interface and the iPad
   split layout.
6. Record VoiceOver and keyboard acceptance for the conversation actions on
   physical hardware.
7. Complete physical-device, remote-delivery, and Mac acceptance before
   considering public submission.

Delivery status changes must cite a command result, App Store Connect record, or
named approval. A passing build does not imply release approval.
