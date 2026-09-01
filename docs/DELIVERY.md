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
| Performance baseline and thresholds | `docs/PERFORMANCE_BASELINE.md` |
| App Store screenshots | `docs/screenshots/README.md` |
| Push gateway deployment and API contract | `Gateway/README.md` |

## Delivery gates

| Gate | Required evidence | Current state |
|---|---|---|
| G1 Repository foundation | Shared scheme, scripts, CI, documentation | Implemented |
| G2 Secure connection | Profile validation, Keychain token, profile persistence | Implemented and locally verified |
| G3 Conversation list | Real list, paging, filters, clear states | Implemented and locally verified |
| G4 Automated quality | macOS and iOS builds, unit tests, UI tests, performance checks | The current source passes macOS and iOS Simulator builds, 192 Swift tests in 19 suites including the performance regression checks, 18 Node gateway tests, and the 4 macOS UI tests including the conversation journey and the cold-launch metric; the three opt-in live compatibility tests are skipped by design. The recorded iPhone and iPad UI journeys have not been re-run on hardware since the conversation actions and the iPad split layout were added |
| G5 Signed archives | iOS and macOS Organizer validation | Blocked. Both the iOS and macOS App Store distribution profiles for `dev.n85.wootdesk` lack the Push Notifications capability, so neither platform can produce a distributable archive. See "Signing blocker" below |
| G6 TestFlight | Physical-device and Mac acceptance | Not started |
| G7 Product completeness | Message history, replies, private notes, attachments, and conversation triage | Source implementation complete; live acceptance pending |
| G8 Public release | Explicit product, security, and release approval | No-go |
| G9 Remote notifications | Push provider, push-capable signing, and profile-safe physical-device delivery | Client and gateway source implemented; capability, deployment, recipient policy, and physical acceptance pending |

## Signing blocker

WootDesk cannot currently produce a distributable archive on either platform,
and the failure is silent rather than obvious.

`xcodebuild archive` **succeeds** and reports `ARCHIVE SUCCEEDED`. The archive it
produces is signed with the Apple Development certificate and carries
`get-task-allow` and `aps-environment: development`. App Store Connect rejects
such a build. Nothing in the build output says the archive is not
distributable.

The cause is that WootDesk declares the Push Notifications capability, and
neither App Store distribution profile includes it:

| Profile | Kind | `aps-environment` |
|---|---|---|
| `iOS Team Store Provisioning Profile: dev.n85.wootdesk` | App Store distribution | absent |
| `Mac Team Store Provisioning Profile: dev.n85.wootdesk` | App Store distribution | absent |
| `iOS Team Provisioning Profile: dev.n85.wootdesk` | development | `development` |
| `Mac Team Provisioning Profile: dev.n85.wootdesk` | development | absent |

Automatic signing therefore cannot satisfy the entitlements from a distribution
profile and falls back to the development profile. Forcing distribution signing
reports the real cause:

```text
error: Provisioning profile "iOS Team Store Provisioning Profile: dev.n85.wootdesk"
doesn't include the aps-environment entitlement.
```

### Root cause: Xcode has no signed-in Apple Developer account

All four profiles above are Xcode-managed, not manually created. Two facts
establish this: their names use Xcode's managed-profile convention
("Team Provisioning Profile", "Team Store Provisioning Profile"), and the
Profiles list in the Apple Developer portal for this team is **empty**, which is
what a team with only Xcode-managed profiles looks like.

Xcode-managed profiles are refreshed by Xcode itself, not downloaded from the
portal. Refreshing requires a signed-in Apple Developer account, and this build
machine has none: there is no Xcode account session and no App Store Connect API
key. `xcodebuild -allowProvisioningUpdates` therefore cannot regenerate the
managed distribution profile, so it silently reuses the stale cached one and
falls back to the development profile that does satisfy the entitlements.

Push Notifications is already enabled on the `dev.n85.wootdesk` App ID. The
managed iOS development profile carries `aps-environment: development`, and
Apple only writes a capability's entitlement into a profile when the App ID
holds that capability. The two Store profiles are simply stale: they were issued
before the capability was added and have never been refreshed.

### To clear the blocker

1. Sign in to Xcode with the Apple Developer account for team `Z85CK5CNS3`,
   under Xcode, Settings, Accounts. This is the missing piece.
2. Run `script/release_archive.sh --preflight-only --team Z85CK5CNS3`. Automatic
   signing regenerates the managed App Store profiles with the push entitlement
   on the next signed build.
3. If the preflight still reports the missing capability, confirm Push
   Notifications on the App ID at
   `developer.apple.com/account/resources/identifiers`, then retry.

Removing the push capability to force a build through is not an acceptable
workaround. It would ship a build whose notification features silently do
nothing, which contradicts the delivered behaviour recorded under N85-10 and
N85-15.

`script/release_archive.sh` checks all of this before building and reports the
missing capability directly. It also re-checks the archive afterwards and fails
if the result is development signed, so the fallback cannot pass unnoticed.

## Upload and submission position

No build has been uploaded, and no upload path currently exists.

App Store Connect API access is **not granted for this Apple account**. The
Keys page under Access, Integrations reports "Permission is required to access
the App Store Connect API" with a Request Access action, so no API key issuer
exists for this team and no key-based upload is possible. There is also no
Xcode account session and no stored upload credential on this machine.

Clearing this needs the release owner to either request and be granted App Store
Connect API access and create a key, or sign in to Xcode and upload through the
Organizer. Neither is something the build tooling should hold or perform.

Submission to App Review also remains gated on N85-18 AC7, which requires
recorded product, security, and release-owner approvals, and on AC6, which
requires an explicit current authorisation naming the specific build.

## Immediate priorities

1. Sign in to Xcode with the Apple Developer account so automatic signing can
   refresh the managed App Store profiles, which is what currently prevents a
   distributable archive from being created at all.
2. Prepare a dedicated review-only Chatwoot environment with invented data.
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
