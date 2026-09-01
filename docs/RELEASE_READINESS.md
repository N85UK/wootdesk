# WootDesk Release Readiness

Document ID: `WOOT-REL-001`

Status: Blocked for public App Store release

Owner: N85 Dev

Last reviewed: 1 September 2026

## Release details

| Field | Detail |
|---|---|
| Proposed release | 1.0.0 (35 or later); build 34 is the current TestFlight candidate, delivered by CI |
| Release channel | TestFlight first, then App Store after approval |
| Platforms | iOS, iPadOS, macOS |
| Release date | To confirm |
| Repository branch | `main` |
| Public service | Not released |

## Current decision

Public App Store release: **No-go**

The repository now contains paginated message history, replies, private notes,
safe attachment handling, conversation triage, notification routing, the iPad
split layout, localisation, a native APNs client, secure per-profile gateway
enrolment, and a self-hostable WootDesk Push Gateway. The source passes the
complete local CI path.

The signing and API-access blockers recorded in earlier reviews are cleared.
iOS build 24 is distribution signed, uploaded, `IN_BETA_TESTING`, and installed
on one internal tester's device. What remains is acceptance evidence rather
than construction or Apple setup.

Still open: the documented acceptance runs against build 24 are unrecorded; the
gateway has not been deployed and its initial account-wide recipient policy is
not approved for organisations that require per-agent routing; no macOS build
has been uploaded and installer signing lacks the `3rd Party Mac Developer
Installer` identity; a stable Xcode is not installed, which App Review requires
though TestFlight does not; and dedicated-server, listing, privacy,
review-access, and owner-approval gates remain open.

## Current App Store Connect build ledger

Read from the App Store Connect API on 1 September 2026.

| Platform | Version and build | State | Compliance | Tester exposure |
|---|---|---|---|---|
| iOS and iPadOS | 1.0.0 (1) | `VALID`, expired | Missing Compliance | None recorded |
| iOS and iPadOS | 1.0.0 (2) | `VALID`, superseded | `ITSAppUsesNonExemptEncryption = false` | None |
| macOS | 1.0.0 (2) | Local archive only | Not uploaded | None |
| iOS and iPadOS | 1.0.0 (3) | Local archive and App Store export package | Not uploaded | None |
| macOS | 1.0.0 (3) | Local universal archive and signed App Store installer package | Not uploaded; embedded Mac App Store profile matches the bundle | None |
| iOS and iPadOS | 1.0.0 (24) | `VALID`, `IN_BETA_TESTING` | Inherits the build settings declaration | 1 internal tester in group `N85`, state `INSTALLED` |
| iOS and iPadOS | 1.0.0 (34) | `VALID`, `IN_BETA_TESTING`; external `READY_FOR_BETA_SUBMISSION` | Inherits the build settings declaration | Internal group `N85` |

Build 24 carries the current source, including conversation triage,
notification routing, the iPad split layout, localisation, and the performance
regression checks. It was uploaded by an authorised local run of
`script/release_archive.sh` on 1 September 2026.

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
| GO-001 | Automated source checks pass | `./script/ci.sh` re-run on 1 September 2026 evening at commit `d0b8b22`: macOS and generic iOS Simulator builds and **192 Swift tests in 19 suites** passed, with 18 Node gateway tests; the three opt-in live compatibility tests skip by design. The earlier `--with-ui-tests` run added 4 macOS UI tests | Pass |
| GO-002 | Live self-hosted connection works | Maintainer confirmed connection on 30 August 2026, no credential retained | Pass |
| GO-003 | Message history, replies, private notes, and attachments meet Milestone 2 acceptance | Source implementation and mocked tests pass; opt-in live harness exists; dedicated-server and TestFlight acceptance remain | In progress |
| GO-004 | iOS and macOS archives validate locally | Signed build 3 iOS archive and App Store export passed; signed universal build 3 macOS archive and installer export passed with the expected sandbox, runtime, icon, privacy, metadata, installer identity, and embedded profile | Pass |
| GO-005 | Physical-device TestFlight checks pass | Build 24 is `INSTALLED` on one internal tester's device, so the matrix can now be run. No documented acceptance run has been recorded yet | In progress; unblocked, evidence outstanding |
| GO-006 | App Store metadata and screenshots are approved | Final platform metadata | Not started |
| GO-007 | Privacy and export-compliance answers are approved | Builds 2 and 3 declare `ITSAppUsesNonExemptEncryption = false`; App Store privacy answers remain pending | In progress |
| GO-008 | Dedicated App Review server and account are ready | Private review runbook | Not started |
| GO-009 | App Store Connect agreements and roles are ready | Free Apps and Paid Apps agreements are `Active` to 24 July 2027, bank account and tax forms `Active`. The MRDP compliance declaration was answered on 1 September 2026, which cleared the upload refusal. Digital Services Act remains `In Review` on Apple's side and does not block delivery | Pass |
| GO-010 | Product, security, and release owners record Go | Signed decision table below | Not started |
| GO-011 | macOS App Store package exports and validates | Xcode export succeeded; the Apple-issued installer signature validates, the embedded profile matches `dev.n85.wootdesk`, and the payload remains universal | Pass locally, upload pending |
| GO-012 | Remote new-message notifications are private, profile-safe, and reliable | Client and gateway source, deterministic enrolment, rotation, deletion, filtering, and route-isolation tests pass. Push Notifications is confirmed on the App ID and build 24 is signed with it. Gateway deployment, approved recipient policy, and physical delivery remain | In progress; source complete, delivery acceptance blocked |

## Quality checks

| Area | Standard | Current evidence | Status |
|---|---|---|---|
| macOS build | Debug app builds | Generic macOS build passed | Pass |
| iOS build | Generic Simulator destination builds | Generic iOS Simulator build passed | Pass |
| Unit tests | All deterministic tests pass without a live server | 192 Swift tests in 19 suites and 18 Node gateway tests passed on 1 September 2026; the three opt-in live compatibility tests were skipped by design | Pass |
| UI tests | First-run setup and the message/reply journey work without a live server | 4 tests pass on this Apple silicon Mac, including the conversation journey and the cold-launch metric. The iPhone and iPad Simulator journeys last passed before the conversation actions and iPad split layout landed and have not been re-run | Pass on Mac; iPhone and iPad re-run outstanding |
| Swift concurrency | Swift 6 complete strict checking | Project build settings | Configured |
| Accessibility | Labels, keyboard flow, Dynamic Type, VoiceOver states | Code review and UI checks | In review |
| Security | Keychain, HTTPS, sandbox, no secret logging | Security tests and local sandbox launch verification passed | Pass for source build |
| Privacy | No analytics, tracking, or live AI | Manifest copied into macOS and iOS app bundles | Pass for source build |
| Notification system source | Permission, cold-launch routing, secure enrolment, APNs rotation, removal, webhook filtering, and encrypted storage work without exposing tokens or message content | Dedicated Swift client tests, 18 Node gateway tests, and unsigned macOS and iOS Simulator builds | Pass for source; Apple activation, deployment, and devices blocked |
| App icons | Asset catalogue validates on both platforms | Debug and Release platform builds passed | Pass |
| iOS distribution | App Store package signs and exports | Build 24 archived, exported, uploaded, and processed to `VALID` on 1 September 2026, which proves distribution signing end to end | Pass |
| macOS distribution | Sandboxed universal archive validates and exports | Build 3 archive and signed App Store installer export pass; upload has not started | Pass locally, upload pending |
| Real devices | Supported-device behaviour | Build 24 `INSTALLED` on one internal tester's device; no documented matrix run recorded | Unblocked, evidence outstanding |

## Required release test matrix

| Platform | Minimum | Additional coverage | Status |
|---|---|---|---|
| iPhone | iOS 18 | Current supported iOS, small and large Dynamic Type | Build 24 available via TestFlight; run not recorded |
| iPad | iPadOS 18 | Compact and regular layouts, keyboard navigation | Build 24 available via TestFlight; run not recorded |
| Mac | macOS 15 | Apple silicon, keyboard shortcuts, window restoration | Native build, unit tests, and 3 macOS UI tests pass on this Apple silicon host |
| Mac | macOS 15 | Intel where available | Not started |

## Automated verification evidence

Source validation used Xcode 27.0 beta 6, build 27A5252f, with Apple Swift 6.4.
Build 24's acceptance by App Store Connect supersedes the earlier caveat about
whether the source was signable with the push capability: it is.

| Command | Result |
|---|---|
| `xcodegen generate --spec project.yml` | Passed |
| `./script/ci.sh` at commit `d0b8b22`, 1 September 2026 | Generic macOS and iOS Simulator Debug builds, **192 Swift tests in 19 suites**, 18 Node gateway tests, and the dependency policy check passed; the three opt-in live compatibility tests were skipped by design. The earlier `--with-ui-tests` run added 4 macOS UI tests |
| Focused availability regression suite | Eight tests passed, including a confirmed availability mutation followed by profile switching and relaunch, immediate state clearing during the switch, and rejection of a delayed response from the previous profile |
| iPhone Simulator UI suite | 3 UI tests passed, including message history and a stub-confirmed reply without network access |
| iPad Simulator UI suite | 3 UI tests passed after replacing a beta-runner element tap with a semantic centre-coordinate tap |
| macOS UI suite | Passed 3 tests on 31 August 2026 after the documented one-time Automation Mode configuration; XCTest established the automation session without an authentication prompt |
| Invented-data screenshot capture | Release UI built with `--uitesting-conversations`; iPhone images are 1284 by 2778 and iPad images are 2064 by 2752; no network or Keychain access occurred; images remain local and unsubmitted |
| Signed iOS Release archive and local App Store export | Passed for build 3, arm64, iOS 18 minimum, privacy manifest present |
| Signed macOS Release archive | Passed for build 3, universal arm64 and x86_64, macOS 15 minimum, App Sandbox with network and user-selected read-only file access, hardened runtime, icon, privacy manifest, and copyright metadata |
| macOS local App Store package export | Passed on 31 August 2026; one Mac Installer Distribution identity has an accessible private key, the package signature validates, and the embedded Mac App Store profile matches the bundle |
| App Store Connect upload | Build 24 processed to `VALID` and is `IN_BETA_TESTING` with one tester `INSTALLED`. Uploaded by an authorised local run, not by CI |
| Signing and App Store Connect access | An App Store Connect Team Key authenticates (`GET /v1/apps` returns HTTP 200). `PUSH_NOTIFICATIONS` is confirmed on the `dev.n85.wootdesk` App ID. The key refreshes managed profiles during a build, which cleared the earlier stale-profile blocker. The stored distribution `.p12` covers iOS and the macOS app but not the macOS installer |

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
- [x] Push Notifications is enabled on the App ID, confirmed via `GET /v1/bundleIds`, and the managed iOS distribution profile carries the entitlement; the macOS profile is unverified because no macOS build has been uploaded.
- [ ] The push provider, data handling, retention, deletion, and lock-screen content match the approved privacy answers.
- [x] Builds 2 and 3 declare the export-compliance decision as
      `ITSAppUsesNonExemptEncryption = false`.
- [ ] Demo environment contains invented data and no production integration.
- [ ] App Review credentials are entered only in private App Store Connect fields.

## Release risks

The active risks and responses are maintained in
`docs/governance/RISK_REGISTER.md`. The highest release blockers are missing
Milestone 2 live acceptance, unrecorded physical-device evidence against
build 24, missing review-only server access, pending privacy answers, the
unapproved account-wide gateway recipient policy, gateway deployment, the
missing macOS installer identity, the absent stable Xcode required for
submission, and the Apple documentation ambiguity around a single
multiplatform target for universal purchase.

The previously listed blocker of unavailable distribution identities and stale
profiles is cleared.

The source includes the native notification client and WootDesk Push Gateway.
Apple activation and push-capable signing are now confirmed. Remote new-message
delivery remains blocked until an approved recipient policy, a hardened
deployment, and invented-data physical-device acceptance all pass.

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
