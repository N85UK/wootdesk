# WootDesk Release Readiness

Document ID: `WOOT-REL-001`

Status: Both platforms rejected and not yet resubmitted. macOS rejected for information on 5 September 2026; iOS found rejected on 10 September, reason not yet read

Owner: N85 Dev

Last reviewed: 10 September 2026

## Release details

| Field | Detail |
|---|---|
| Proposed release | 1.0.0. Current candidates are iOS build 111 and macOS build 112, both delivered by CI on Xcode 26.6.0 and `VALID` on 8 September 2026 |
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
| GO-001 | Automated source checks pass | CI passed at `182e20f` on 8 September 2026. The same day, local runs passed **230 Swift tests in 24 suites** on the iOS Simulator and **57 Node gateway tests**. The three opt-in live compatibility tests skip by design | Pass |
| GO-002 | Live self-hosted connection works | Maintainer confirmed connection on 30 August 2026, no credential retained | Pass |
| GO-003 | Message history, replies, private notes, and attachments meet Milestone 2 acceptance | **Verified against a live Chatwoot v4.9.0 server** on 2 September 2026. All three opt-in compatibility cases passed, covering history, public replies, private notes, attachments, availability and triage, with both write gates set. TestFlight device acceptance remains | Pass against the dedicated server |
| GO-004 | iOS and macOS archives validate locally | Superseded by stronger evidence. CI archives, exports and uploads both platforms on Xcode 26.6.0, and App Store Connect accepted iOS build 111 and macOS build 112 as `VALID` on 8 September 2026. The macOS archive is universal, compiled for arm64 and x86_64. The build 3 local archives this row previously cited predate the push capability | Pass |
| GO-005 | Physical-device TestFlight checks pass | **iPhone and iPad both passed on hardware**, 4 of 4 UI journeys each: iPhone 17 Pro Max on iOS 27.0 with a real push notification delivered, and iPad Pro 13-inch (M4) on iPadOS 27.0. Apple silicon Mac passed the same suite. **Intel Mac recorded as unavailable on 10 September 2026**, because no Intel hardware is available. Manual acceptance cases outstanding | Pass on iPhone, iPad and Apple silicon Mac; Intel unavailable |
| GO-013 | App Review outcome | **macOS 1.0 build 100 was rejected on 5 September 2026 under Guideline 2.1, Information Needed.** Not a functional defect: the notice states the developer account has a limited App Review history and asks for a screen recording plus written answers on purpose, setup, external services, regional differences and regulated material. Answers to items 2 to 6 are in the App Review Notes on **both** platforms. **Build 112 was attached on 10 September 2026**, replacing 109, because it is the first macOS build to send the agent identity when refreshing an APNs token, which the gateway otherwise refuses with HTTP 400. The screen recording on a physical device should be made against 112 and is the account holder's to make. **iOS 1.0 was also found `REJECTED` on 10 September**, still carrying build 98, which predates both the removal of the unimplemented AI settings section and the token refresh fix. Its reason is not exposed by the API | Blocked on a screen recording; iOS rejection reason unread |
| GO-006 | App Store metadata and screenshots are approved | **Both platforms submitted on 4 September 2026**: iOS with build 98 and macOS with build 100, each with description, keywords and screenshots. **Both are now rejected**: macOS on 5 September for information, see GO-013, and iOS found `REJECTED` when App Store Connect was read on 10 September. The API exposes neither the reason nor the date of the iOS rejection, so it must be read in the Resolution Center. Both review submissions are `UNRESOLVED_ISSUES`. Owner approval of this content belongs to GO-010 | Both rejected; neither resubmitted |
| GO-007 | Privacy and export-compliance answers are approved | **Export compliance:** the current source declares `ITSAppUsesNonExemptEncryption = false` in `Info-Release.plist`, verified 10 September 2026. **Privacy:** the answer was corrected on 3 September to declare Device ID and User ID, collected for App Functionality, linked to the user and not used for tracking, because the push gateway stores both. It replaced the earlier "Data Not Collected" answer. The API cannot set privacy fields, so the answer is entered by hand, and **no record confirms App Store Connect was updated**. Check App Privacy before resubmitting: an App Store answer that disagrees with the privacy manifest in the build is a mismatch App Review can raise | Decided; App Store Connect entry unconfirmed |
| GO-008 | Dedicated App Review server and account are ready | **Ready.** `review.n85.app` is defined in `review/` and returned HTTP 200 on 10 September 2026. The demo account name and password are set on both platforms, with `demoAccountRequired` true, confirmed by reading App Store Connect on 10 September; the 3 September record of them being empty is superseded. They were checked for presence only, not for whether they still authenticate against the server | Server ready; credentials set |
| GO-009 | App Store Connect agreements and roles are ready | Free Apps and Paid Apps agreements are `Active` to 24 July 2027, bank account and tax forms `Active`. The MRDP compliance declaration was answered on 1 September 2026, which cleared the upload refusal. **Digital Services Act trader verification failed on 4 September 2026** and no longer reads `In Review`. Apple Developer Support, case 20000152699489, gave the reason: the address entered in App Store Connect does not match the supporting documentation supplied. Neither app on the account is live, both being `PREPARE_FOR_SUBMISSION`, so nothing is being withdrawn from sale; the notice's warning about remaining available in the EU is boilerplate. It blocks EU release rather than delivery, and it is the account holder's to resolve in App Store Connect under Business, legal entity, Agreements, Compliance | Blocked for EU release |
| GO-010 | Product, security, and release owners record Go | Signed decision table below, still pending. **Both platforms were submitted on 4 September 2026 before any decision was recorded**, so the table now records approval after submission rather than before it | Not started |
| GO-011 | macOS App Store package exports and validates | CI exports and uploads the macOS package. Builds 100, 109 and 112 are on App Store Connect's macOS build list as `VALID`, verified 8 September 2026. The archive is universal, compiled for arm64 and x86_64 | Pass |
| GO-012 | Remote new-message notifications are private, profile-safe, and reliable | Per-agent routing per `DEC-008`: an assigned conversation reaches only the assignee, an unassigned one reaches every agent on the account. **Real APNs delivery has been exercised** on a physical iPhone, with three routing cases run against the live gateway, including the isolation proof. **Deployment scoping (N85-64) went live on 8 September 2026**: notifications route per Chatwoot deployment, proven end to end against a second deployment, and the one existing production registration was attributed on upgrade. iOS build 110 and macOS build 112 are the first to send the agent identity when refreshing an APNs token; earlier builds had refresh refused with HTTP 400. That production registration carries no agent identity, so its device must re-enrol on a build carrying the fix, iOS 110 or macOS 112 onwards, before assigned conversations reach it. 57 gateway tests and 230 Swift tests pass, and the payload carries no message content. Outstanding: delivery to a physical **iPad and Mac**, and a second physical handset for the negative case, which used a stand-in token | In progress; iPhone delivery proven, iPad and Mac delivery outstanding |

## Quality checks

| Area | Standard | Current evidence | Status |
|---|---|---|---|
| macOS build | Debug app builds | Generic macOS build passed | Pass |
| iOS build | Generic Simulator destination builds | Generic iOS Simulator build passed | Pass |
| Unit tests | All deterministic tests pass without a live server | 192 Swift tests in 19 suites and 18 Node gateway tests passed on 1 September 2026; the three opt-in live compatibility tests were skipped by design | Pass |
| UI tests | First-run setup and the message/reply journey work without a live server | 4 tests pass on this Apple silicon Mac, and on 1 September 2026 all 4 passed again on an iPhone 17 Pro simulator and an iPad Pro 13-inch simulator against the current source | Pass on Mac, iPhone and iPad simulators; physical hardware outstanding |
| Swift concurrency | Swift 6 complete strict checking | Project build settings | Configured |
| Accessibility | Labels, keyboard flow, Dynamic Type, VoiceOver states | Dynamic Type exercised on iPad and iPhone simulators at `accessibility-extra-large` on 1 September 2026. Found and fixed a defect where conversation row badges wrapped to one character per line; the status filter menu fallback and the horizontally scrolling action row both behaved correctly. VoiceOver and keyboard acceptance on hardware remain | Dynamic Type verified on simulators; VoiceOver and keyboard outstanding |
| Security | Keychain, HTTPS, sandbox, no secret logging | Security tests and local sandbox launch verification passed | Pass for source build |
| Privacy | No analytics, tracking, or live AI | Manifest copied into macOS and iOS app bundles | Pass for source build |
| Notification system source | Permission, cold-launch routing, secure enrolment, APNs rotation, removal, webhook filtering, and encrypted storage work without exposing tokens or message content | Dedicated Swift client tests, 18 Node gateway tests, and unsigned macOS and iOS Simulator builds | Pass for source; Apple activation, deployment, and devices blocked |
| App icons | Asset catalogue validates on both platforms | Debug and Release platform builds passed | Pass |
| iOS distribution | App Store package signs and exports | Build 24 archived, exported, uploaded, and processed to `VALID` on 1 September 2026, which proves distribution signing end to end | Pass |
| macOS distribution | Sandboxed universal archive validates and exports | CI archives, exports and uploads a universal arm64 and x86_64 package; builds 100, 109 and 112 are `VALID` on App Store Connect | Pass |
| Real devices | Supported-device behaviour | **Passed on hardware on 3 September 2026**: 4 of 4 UI journeys on an iPhone 17 Pro Max running iOS 27.0, plus a real APNs notification on 2 September, and 4 of 4 on an iPad Pro 13-inch (M4). Apple silicon Mac passed the UI suite. Intel Mac unavailable, see the test matrix | Passed on iPhone, iPad and Apple silicon Mac; Intel unavailable |

## Required release test matrix

| Platform | Minimum | Additional coverage | Status |
|---|---|---|---|
| iPhone | iOS 18 | Current supported iOS, small and large Dynamic Type | **Passed on hardware, 3 September 2026.** iPhone 17 Pro Max, iOS 27.0 build 24A5430a, 4 of 4 UI journeys including the conversation history and reply flow and the cold-launch metric. Dynamic Type on hardware still outstanding |
| iPad | iPadOS 18 | Compact and regular layouts, keyboard navigation | **Passed on hardware, 3 September 2026.** iPad Pro 13-inch (M4), iPadOS 27.0 build 24A5424a, 4 of 4 UI journeys. Manual cases outstanding |
| Mac | macOS 15 | Apple silicon, keyboard shortcuts, window restoration | Native build, unit tests, and 3 macOS UI tests pass on this Apple silicon host |
| Mac | macOS 15 | Intel where available | **Unavailable, recorded 10 September 2026.** No Intel Mac is available to the project, and N85-18 AC4 accepts an unavailable result. The shipped macOS build is universal, so its x86_64 code is compiled by CI and reaches Intel users, but it has never run on Intel hardware: a defect specific to Intel would not have been seen |

## Automated verification evidence

Release builds are produced by CI on **Xcode 26.6.0**, a stable release, which
App Review requires. Verified from the logs of the runs that uploaded iOS build
111 and macOS build 112 on 8 September 2026.

The rows after the first are dated evidence from earlier stages, kept as
history. That earlier source validation used Xcode 27.0 beta 6, build 27A5252f,
with Apple Swift 6.4. Build 24's acceptance by App Store Connect settled whether
the source was signable with the push capability: it is.

| Command | Result |
|---|---|
| CI release builds, 8 September 2026 | iOS build 111 and macOS build 112 archived, exported and uploaded by `.github/workflows/testflight.yml` on Xcode 26.6.0; both `VALID` on App Store Connect. CI passed at `182e20f` |
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
| Signing and App Store Connect access | An App Store Connect Team Key authenticates (`GET /v1/apps` returns HTTP 200). `PUSH_NOTIFICATIONS` is confirmed on the `dev.n85.wootdesk` App ID. The `3rd Party Mac Developer Installer` certificate **exists on the team and its private key is present on the maintainer's Mac**, so macOS installer signing is not blocked; it is simply absent from the CI secret bundle. Seventeen CI-created development certificates were revoked across 2 and 3 September after the account hit Apple's cap and every build began failing. Fixed at the root on 3 September: the iOS archive signs manually against the `WootDesk iOS App Store` profile, so the release path no longer provisions for development and mints nothing |

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
