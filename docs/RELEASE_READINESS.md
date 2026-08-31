# WootDesk Release Readiness

Document ID: `WOOT-REL-001`

Status: Blocked for public App Store release

Owner: N85 Dev

Last reviewed: 31 August 2026

## Release details

| Field | Detail |
|---|---|
| Proposed release | 1.0.0 (4 or later) |
| Release channel | TestFlight first, then App Store after approval |
| Platforms | iOS, iPadOS, macOS |
| Release date | To confirm |
| Repository branch | `main` |
| Public service | Not released |

## Current decision

Public App Store release: **No-go**

The repository now contains paginated message history, replies, private notes,
safe attachment handling, a native APNs client, secure per-profile gateway
enrolment, and a self-hostable WootDesk Push Gateway. Build 4 source passes the
complete local CI path, but it has not been signed, archived, uploaded, or
tested on physical devices. The gateway has not been deployed and its initial
account-wide recipient policy is not approved for organisations that require
per-agent routing. The signed iOS build 2 TestFlight candidate predates the
message and notification work, has no testers, and is not approved for public
release. Apple capability, provisioning, deployment, dedicated-server,
physical-device, listing, privacy, review-access, and owner-approval gates
remain open.

## Current App Store Connect build ledger

| Platform | Version and build | State | Compliance | Tester exposure |
|---|---|---|---|---|
| iOS and iPadOS | 1.0.0 (1) | Superseded | Missing Compliance | None recorded |
| iOS and iPadOS | 1.0.0 (2) | Ready to Submit | `ITSAppUsesNonExemptEncryption = false` | None |
| macOS | 1.0.0 (2) | Local archive only | Not uploaded | None |
| iOS and iPadOS | 1.0.0 (3) | Local archive and App Store export package | Not uploaded | None |
| macOS | 1.0.0 (3) | Local universal archive and signed App Store installer package | Not uploaded; embedded Mac App Store profile matches the bundle | None |

No platform version has been submitted for App Review.

## Included scope

- `REQ-CONN-001`: Add and validate a Chatwoot server.
- `REQ-CONN-002`: Select one of several accounts.
- `REQ-SEC-001`: Store access tokens only in Apple Keychain.
- `REQ-PROFILE-001`: Restore, switch, edit, revalidate, and remove profiles.
- `REQ-CONV-001`: Load and display a real conversation list.
- `REQ-MSG-001`: Load and page message history for a selected conversation.
- `REQ-REPLY-001`: Send a plain-text agent reply or private note with safe draft handling.
- `REQ-ATTACH-001`: Upload files and present received attachment metadata without automatic remote fetch.
- `REQ-MSG-SAFE-001`: Present processed HTML and inline Markdown without active embedded links.
- `REQ-PUSH-CLIENT-001`: Request notification permission, register with APNs, and expose accurate local and provider-required states without persisting the device token.
- `REQ-PUSH-GATEWAY-001`: Enrol and remove a saved profile through an authenticated gateway that encrypts APNs tokens and emits generic alerts.
- `REQ-DIST-001`: Include valid iOS, iPadOS, and macOS app icons.
- `REQ-PRIV-001`: Ship without analytics, tracking, or live AI requests.

## Excluded scope

- Arbitrary HTML, remote media previews, and active links inside message content.
- Assignment, labels, teams, and status mutation.
- ActionCable real-time updates, a live hosted gateway service, approved per-agent recipient routing, and background refresh.
- Live AI features or an AI Gateway.
- Offline conversation storage.
- Developer ID distribution outside the Mac App Store.

## Go or no-go criteria

| ID | Criterion | Evidence | Status |
|---|---|---|---|
| GO-001 | Automated source checks pass | A source-only snapshot passed `./script/ci.sh --with-ui-tests`, including 18 Node gateway tests, 126 Swift tests, and 3 macOS UI tests; the previously recorded iPhone and iPad UI journeys also pass | Pass |
| GO-002 | Live self-hosted connection works | Maintainer confirmed connection on 30 August 2026, no credential retained | Pass |
| GO-003 | Message history, replies, private notes, and attachments meet Milestone 2 acceptance | Source implementation and mocked tests pass; opt-in live harness exists; dedicated-server and TestFlight acceptance remain | In progress |
| GO-004 | iOS and macOS archives validate locally | Signed build 3 iOS archive and App Store export passed; signed universal build 3 macOS archive and installer export passed with the expected sandbox, runtime, icon, privacy, metadata, installer identity, and embedded profile | Pass |
| GO-005 | Physical-device TestFlight checks pass | Test matrix and tester sign-off | Not started |
| GO-006 | App Store metadata and screenshots are approved | Final platform metadata | Not started |
| GO-007 | Privacy and export-compliance answers are approved | Builds 2 and 3 declare `ITSAppUsesNonExemptEncryption = false`; App Store privacy answers remain pending | In progress |
| GO-008 | Dedicated App Review server and account are ready | Private review runbook | Not started |
| GO-009 | App Store Connect agreements and roles are ready | App record and build upload succeeded; final agreement and role review remains pending | In progress |
| GO-010 | Product, security, and release owners record Go | Signed decision table below | Not started |
| GO-011 | macOS App Store package exports and validates | Xcode export succeeded; the Apple-issued installer signature validates, the embedded profile matches `dev.n85.wootdesk`, and the payload remains universal | Pass locally, upload pending |
| GO-012 | Remote new-message notifications are private, profile-safe, and reliable | Client and gateway source, deterministic enrolment, rotation, deletion, filtering, and route-isolation tests pass; Apple capability, approved recipient policy, deployment, signed build 4, and physical delivery remain | In progress; source complete, live acceptance blocked |

## Quality checks

| Area | Standard | Current evidence | Status |
|---|---|---|---|
| macOS build | Debug app builds | Generic macOS build passed | Pass |
| iOS build | Generic Simulator destination builds | Generic iOS Simulator build passed | Pass |
| Unit tests | All deterministic tests pass without a live server | 126 Swift tests in 14 suites and 18 Node gateway tests passed; the two opt-in live compatibility tests were skipped by design | Pass |
| UI tests | First-run setup and the message/reply journey work without a live server | 3 tests passed on an iPhone 17 Pro Simulator, 3 passed on an iPad Pro 13-inch Simulator, and 3 passed on this Apple silicon Mac after the controlled Automation Mode setup | Pass on iPhone, iPad, and this Mac |
| Swift concurrency | Swift 6 complete strict checking | Project build settings | Configured |
| Accessibility | Labels, keyboard flow, Dynamic Type, VoiceOver states | Code review and UI checks | In review |
| Security | Keychain, HTTPS, sandbox, no secret logging | Security tests and local sandbox launch verification passed | Pass for source build |
| Privacy | No analytics, tracking, or live AI | Manifest copied into macOS and iOS app bundles | Pass for source build |
| Notification system source | Permission, cold-launch routing, secure enrolment, APNs rotation, removal, webhook filtering, and encrypted storage work without exposing tokens or message content | Dedicated Swift client tests, 18 Node gateway tests, and unsigned macOS and iOS Simulator builds | Pass for source; Apple activation, deployment, and devices blocked |
| App icons | Asset catalogue validates on both platforms | Debug and Release platform builds passed | Pass |
| iOS distribution | App Store package signs and exports | Build 3 local archive and App Store package export passed; build 2 remains the only uploaded build | Pass locally, upload pending |
| macOS distribution | Sandboxed universal archive validates and exports | Build 3 archive and signed App Store installer export pass; upload has not started | Pass locally, upload pending |
| Real devices | Supported-device behaviour | TestFlight matrix | Not started |

## Required release test matrix

| Platform | Minimum | Additional coverage | Status |
|---|---|---|---|
| iPhone | iOS 18 | Current supported iOS, small and large Dynamic Type | Not started |
| iPad | iPadOS 18 | Compact and regular layouts, keyboard navigation | Not started |
| Mac | macOS 15 | Apple silicon, keyboard shortcuts, window restoration | Native build, unit tests, and 3 macOS UI tests pass on this Apple silicon host |
| Mac | macOS 15 | Intel where available | Not started |

## Automated verification evidence

Build 4 source validation used Xcode 27.0 beta 6, build 27A5252f, with Apple
Swift 6.4. The signed build 3 archive evidence is historical and does not prove
that build 4 is signable with the refreshed push capability.

| Command | Result |
|---|---|
| `xcodegen generate --spec project.yml` | Passed |
| `./script/ci.sh --with-ui-tests` from a source-only snapshot | Build 4 generic macOS and iOS Simulator Debug builds, 126 Swift tests in 14 suites, 18 Node gateway tests, the dependency policy check, and 3 macOS UI tests passed; the two opt-in live compatibility tests were skipped by design |
| Focused availability regression suite | Eight tests passed, including a confirmed availability mutation followed by profile switching and relaunch, immediate state clearing during the switch, and rejection of a delayed response from the previous profile |
| iPhone Simulator UI suite | 3 UI tests passed, including message history and a stub-confirmed reply without network access |
| iPad Simulator UI suite | 3 UI tests passed after replacing a beta-runner element tap with a semantic centre-coordinate tap |
| macOS UI suite | Passed 3 tests on 31 August 2026 after the documented one-time Automation Mode configuration; XCTest established the automation session without an authentication prompt |
| Invented-data screenshot capture | Release UI built with `--uitesting-conversations`; iPhone images are 1284 by 2778 and iPad images are 2064 by 2752; no network or Keychain access occurred; images remain local and unsubmitted |
| Signed iOS Release archive and local App Store export | Passed for build 3, arm64, iOS 18 minimum, privacy manifest present |
| Signed macOS Release archive | Passed for build 3, universal arm64 and x86_64, macOS 15 minimum, App Sandbox with network and user-selected read-only file access, hardened runtime, icon, privacy manifest, and copyright metadata |
| macOS local App Store package export | Passed on 31 August 2026; one Mac Installer Distribution identity has an accessible private key, the package signature validates, and the embedded Mac App Store profile matches the bundle |
| App Store Connect upload | Build 2 processed and is Ready to Submit |
| Current local signing inventory | `security find-identity -p codesigning -v` reported zero valid identities and no local provisioning profiles were found on 31 August 2026; build 4 distribution is blocked until approved identities and refreshed profiles are available |

Xcode emitted its normal destination-selection warning because the Mac can be
addressed as either arm64 or x86_64, and a metadata-extraction warning because
the app does not link App Intents. Neither warning represented a compile, test,
asset, privacy-manifest, or signing error.

## Security and privacy release checks

- [ ] No token, demo credential, real server address, or customer data exists in
      Git history, source, fixtures, documentation, screenshots, or CI output.
- [ ] Release URL policy rejects non-HTTPS servers.
- [ ] Release archive contains the expected macOS sandbox entitlements only.
- [ ] Keychain access works with App Store provisioning on iOS and macOS.
- [ ] Privacy manifest matches the exact release binary.
- [ ] Public privacy-policy URL is accessible without authentication.
- [ ] App Store privacy answers match all platforms and linked services.
- [ ] Push Notifications is enabled on the App ID and refreshed iOS and macOS profiles contain the production APNs entitlement.
- [ ] The push provider, data handling, retention, deletion, and lock-screen content match the approved privacy answers.
- [x] Builds 2 and 3 declare the export-compliance decision as
      `ITSAppUsesNonExemptEncryption = false`.
- [ ] Demo environment contains invented data and no production integration.
- [ ] App Review credentials are entered only in private App Store Connect fields.

## Release risks

The active risks and responses are maintained in
`docs/governance/RISK_REGISTER.md`. The highest release blockers are missing
Milestone 2 live acceptance, missing physical-device evidence, missing
review-only server access, pending privacy answers, unavailable current local
distribution identities and profiles, the unapproved account-wide gateway
recipient policy, gateway deployment, and the Apple documentation ambiguity
around a single multiplatform target for universal purchase.

Build 4 source includes the native notification client and WootDesk Push
Gateway. Remote new-message delivery remains blocked until Apple activation,
approved recipient policy, a hardened deployment, signed-build inspection, and
invented-data physical-device acceptance all pass.

## Rollback and stop conditions

Before public release, rollback means removing a TestFlight build from tester
access and preparing a corrected build with a higher build number. Do not reuse
an uploaded build number.

Stop the release if:

- An archive contains an unexpected entitlement or identifier.
- A token or real customer data appears in any artefact.
- The privacy answer differs from observed network behaviour.
- App Review cannot reach the dedicated demo environment.
- Profile switching can display data from the wrong server.
- A notification can route to the wrong profile, account, user, device, or APNs environment.
- A build presents remote Chatwoot delivery as active before gateway enrolment and physical-device delivery succeed.
- Keychain deletion or profile rollback fails.
- A critical or high-severity defect remains open.

## Approval

| Role | Name | Decision | Date | Conditions |
|---|---|---|---|---|
| Product owner | To confirm | Pending | | |
| Technical owner | To confirm | Pending | | |
| Security reviewer | To confirm | Pending | | |
| Release owner | To confirm | Pending | | |

No row may be inferred from a build passing. Each owner must record an explicit
decision against the final release commit.
