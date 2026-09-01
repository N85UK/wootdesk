# WootDesk Delivery Index

Document ID: `WOOT-INDEX-001`

Status: In review

Owner: N85 Dev

Last reviewed: 1 September 2026, evening

## Current delivery position

Milestone 1 provides the complete connection and conversation-list vertical
slice. The Milestone 2 source now provides paginated message history, public
replies, private notes, safe inline message presentation, and file attachment
upload and display boundaries. The maintainer has confirmed a live connection
to a self-hosted Chatwoot server, but the new message workflow has not yet
completed dedicated invented-data server or TestFlight acceptance.

User-facing text is now catalogued. British English is the source language,
`Localizable.xcstrings` holds 266 strings and compiles to an `en-GB.lproj` in
the app bundle, and every string produced outside a SwiftUI `Text` literal is
resolved through the localisation system. Only British English ships; a
partially translated language is deliberately not included. A documented
performance baseline and its regression checks are recorded in
`docs/PERFORMANCE_BASELINE.md` and run as part of the normal suite.

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

The source adds the native notification client, secure device enrolment, and
the self-hostable authenticated WootDesk Push Gateway. Push Notifications is
confirmed enabled on the App ID and the managed distribution profile now
carries it. Remote Chatwoot new-message delivery is still not active, because
gateway deployment, recipient-policy approval, and physical-device delivery
acceptance remain open.

iOS build 24 carries this source and is on TestFlight, `IN_BETA_TESTING`, with
one internal tester having it installed. It is not approved for a public App
Store release. No macOS build has been uploaded.

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
| Performance baseline and thresholds | `docs/PERFORMANCE_BASELINE.md` |
| App Store screenshots | `docs/screenshots/README.md` |
| TestFlight delivery pipeline | `docs/TESTFLIGHT_DELIVERY.md` |
| Push gateway deployment and API contract | `Gateway/README.md` |

## Delivery gates

| Gate | Required evidence | Current state |
|---|---|---|
| G1 Repository foundation | Shared scheme, scripts, CI, documentation | Implemented |
| G2 Secure connection | Profile validation, Keychain token, profile persistence | Implemented and locally verified |
| G3 Conversation list | Real list, paging, filters, clear states | Implemented and locally verified |
| G4 Automated quality | macOS and iOS builds, unit tests, UI tests, performance checks | The current source passes macOS and iOS Simulator builds, **194 Swift tests in 19 suites** including the performance regression checks, 18 Node gateway tests, and the 4 UI tests. On 1 September 2026 the UI suite was re-run on iPhone 17 Pro and iPad Pro 13-inch simulators, 4 of 4 passing on each, which closes the earlier caveat that the iPhone and iPad journeys predated the conversation actions and the iPad split layout. Physical-hardware runs remain outstanding. The three opt-in live compatibility tests are skipped by design |
| G5 Signed archives | iOS and macOS Organizer validation | Cleared for iOS. An App Store Connect API key now refreshes the managed profiles during the build, so iOS produces a distribution-signed archive. Build 24 was accepted by App Store Connect on 1 September 2026, which is the proof. macOS installer signing still needs the `3rd Party Mac Developer Installer` identity |
| G6 TestFlight | Physical-device and Mac acceptance | Automated delivery works. `.github/workflows/testflight.yml` is armed and run 33544372320 uploaded build 34, now `VALID` and `IN_BETA_TESTING`. Every green push to `main` now delivers. Build 24 remains `INSTALLED` on one internal tester's device. Documented acceptance runs are still unrecorded, and that is now the gating item |
| G7 Product completeness | Message history, replies, private notes, attachments, and conversation triage | Source implementation complete; live acceptance pending |
| G8 Public release | Explicit product, security, and release approval | No-go |
| G9 Remote notifications | Push provider, push-capable signing, and profile-safe physical-device delivery | Client and gateway source implemented. Push Notifications is confirmed enabled on the `dev.n85.wootdesk` App ID, and build 24 signs with it. Gateway deployment, recipient-policy approval, and physical delivery acceptance remain |

## Signing, resolved

This section previously recorded a blocker: `xcodebuild archive` reported
`ARCHIVE SUCCEEDED` while silently producing a development-signed archive
carrying `get-task-allow` and `aps-environment: development`, because both
App Store distribution profiles for `dev.n85.wootdesk` were stale and lacked
the push entitlement.

The blocker is cleared, and the fix was not the one first proposed. Signing in
to Xcode was never required. An App Store Connect API key lets `xcodebuild
-allowProvisioningUpdates` regenerate the managed distribution profile during
the build, so the stale cached profile is replaced rather than reused.

Verified on 1 September 2026:

| Check | Result |
|---|---|
| App Store Connect API key authenticates | `GET /v1/apps` returns HTTP 200 and lists `dev.n85.wootdesk` |
| Push Notifications on the App ID | Present. `GET /v1/bundleIds` reports `PUSH_NOTIFICATIONS` and `IN_APP_PURCHASE` |
| Distribution-signed archive | iOS build 24 was accepted and processed by App Store Connect, which rejects a development-signed upload |

`script/release_archive.sh` still checks the entitlements before building and
re-checks the exported package afterwards, so a development-signed fallback
cannot pass unnoticed.

Removing the push capability to force a build through remains unacceptable. It
would ship a build whose notification features silently do nothing, which
contradicts the delivered behaviour recorded under N85-10 and N85-15.

### Still outstanding for macOS

The stored distribution `.p12` carries the Apple Distribution identity only.
Signing a macOS **installer package** additionally needs the
`3rd Party Mac Developer Installer` identity, which is not in the stored
material. iOS TestFlight delivery does not need it.

## Toolchain blocker

Only beta Xcode versions are installed on this machine:

| Path | Version |
|---|---|
| `/Applications/Xcode-beta.app` (active) | 27.0 beta |
| `/Applications/Xcode-27-beta-1.app` | 27.0 beta |

Apple does not accept App Store submissions built with a beta Xcode outside
specific transition windows, and N85-18 AC2 requires the approved stable Xcode
version. A stable Xcode must be installed and selected with `xcode-select`
before a submission build is created. `script/release_archive.sh` checks this
first, ahead of the signing checks, so the problem surfaces before any build
time is spent.

This does not affect `script/ci.sh`. Building and testing on a beta toolchain is
fine; only submission is restricted.

## Upload and submission position

App Store Connect API access **is granted** for this team and a Team Key is in
use. The earlier record of "Permission is required to access the App Store
Connect API" is superseded.

Current App Store Connect state, read from the API on 1 September 2026:

| Build | State | Beta state | Uploaded | Tester exposure |
|---|---|---|---|---|
| iOS 24 | `VALID` | `IN_BETA_TESTING`, external `READY_FOR_BETA_SUBMISSION` | 1 September 2026 | 1 internal tester in group `N85`, `INSTALLED` |
| iOS 2 | `VALID` | Superseded | 30 August 2026 | None |
| iOS 1 | `VALID`, expired | Superseded | 30 August 2026 | None |

Build 24 was uploaded by an authorised local run of
`script/release_archive.sh`, not by CI. It carries the current source,
including conversation triage, notification routing, the iPad split layout,
localisation, and the performance checks.

No macOS build has been uploaded.

Submission to App Review remains gated on N85-18 AC7, which requires recorded
product, security, and release-owner approvals, on AC6, which requires an
explicit current authorisation naming the specific build, and on the stable
Xcode requirement in AC2.

## Immediate priorities

1. Record the documented acceptance runs against build 34 on physical iPhone
   and iPad. This is the evidence N85-18 AC3 needs, it requires no further
   Apple setup, and it is now the largest single gap.
2. Trust the compatibility CA with `script/compat_env.sh trust`, then run the
   live matrix. The server is verified and seeded; this is the only remaining
   step. Unblocks N85-17 AC3 to AC5 and the live acceptance on N85-11.
3. Review and deploy the implemented Chatwoot-to-APNs gateway with approved
   Apple credentials, host secret storage, proxy-log redaction, and a recipient
   policy suitable for the deployment.
4. Re-run the iPhone and iPad UI journeys on hardware against the current
   source, and record VoiceOver and keyboard acceptance for the conversation
   actions.
5. Add the `3rd Party Mac Developer Installer` identity before enabling macOS
   delivery.
6. Install a stable Xcode before creating any App Store submission build.
   TestFlight does not require it.
7. Complete physical-device, remote-delivery, and Mac acceptance before
   considering public submission.

Delivery status changes must cite a command result, App Store Connect record, or
named approval. A passing build does not imply release approval.
