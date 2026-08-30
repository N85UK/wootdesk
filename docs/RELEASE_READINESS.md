# WootDesk Release Readiness

Document ID: `WOOT-REL-001`

Status: Blocked for public App Store release

Owner: N85 Dev

Last reviewed: 30 August 2026

## Release details

| Field | Detail |
|---|---|
| Proposed release | 1.0.0 (2) |
| Release channel | TestFlight first, then App Store after approval |
| Platforms | iOS, iPadOS, macOS |
| Release date | To confirm |
| Repository branch | `codex/app-store-submission` |
| Public service | Not released |

## Current decision

Public App Store release: **No-go**

The foundation connection and conversation-list slice works, but message
history and replies are not implemented. A signed iOS build 2 TestFlight
candidate exists and is marked Ready to Submit, but it has no testers and is not
approved for public release. Feature, privacy, demo access, physical-device,
macOS distribution, and owner-approval gates remain open.

## Current App Store Connect build ledger

| Platform | Version and build | State | Compliance | Tester exposure |
|---|---|---|---|---|
| iOS and iPadOS | 1.0.0 (1) | Superseded | Missing Compliance | None recorded |
| iOS and iPadOS | 1.0.0 (2) | Ready to Submit | `ITSAppUsesNonExemptEncryption = false` | None |
| macOS | 1.0.0 (2) | Local archive only | Not uploaded | None |

No platform version has been submitted for App Review.

## Included scope

- `REQ-CONN-001`: Add and validate a Chatwoot server.
- `REQ-CONN-002`: Select one of several accounts.
- `REQ-SEC-001`: Store access tokens only in Apple Keychain.
- `REQ-PROFILE-001`: Restore, switch, edit, revalidate, and remove profiles.
- `REQ-CONV-001`: Load and display a real conversation list.
- `REQ-DIST-001`: Include valid iOS, iPadOS, and macOS app icons.
- `REQ-PRIV-001`: Ship without analytics, tracking, or live AI requests.

## Excluded scope

- Message history, replies, private notes, and attachments.
- Assignment, labels, teams, and status mutation.
- Real-time updates, push notifications, and background refresh.
- Live AI features or an AI Gateway.
- Offline conversation storage.
- Developer ID distribution outside the Mac App Store.

## Go or no-go criteria

| ID | Criterion | Evidence | Status |
|---|---|---|---|
| GO-001 | Foundation automated checks pass | `./script/ci.sh --with-ui-tests`, 61 unit tests and 2 UI tests on 30 August 2026 | Pass |
| GO-002 | Live self-hosted connection works | Maintainer confirmed connection on 30 August 2026, no credential retained | Pass |
| GO-003 | Message history and replies meet Milestone 2 acceptance | Milestone 2 test evidence | Blocked |
| GO-004 | iOS and macOS archives validate locally | Signed iOS archive and App Store export passed; signed universal macOS archive, sandbox, runtime, icon, and privacy checks passed | Pass |
| GO-005 | Physical-device TestFlight checks pass | Test matrix and tester sign-off | Not started |
| GO-006 | App Store metadata and screenshots are approved | Final platform metadata | Not started |
| GO-007 | Privacy and export-compliance answers are approved | Build 2 export-compliance declaration is recorded; App Store privacy answers remain pending | In progress |
| GO-008 | Dedicated App Review server and account are ready | Private review runbook | Not started |
| GO-009 | App Store Connect agreements and roles are ready | App record and build upload succeeded; final agreement and role review remains pending | In progress |
| GO-010 | Product, security, and release owners record Go | Signed decision table below | Not started |

## Quality checks

| Area | Standard | Current evidence | Status |
|---|---|---|---|
| macOS build | Debug app builds | Generic macOS build passed | Pass |
| iOS build | Generic Simulator destination builds | Generic iOS Simulator build passed | Pass |
| Unit tests | All deterministic tests pass without a live server | 61 tests in 8 suites passed | Pass |
| UI tests | First-run setup is reachable without a live server | 2 XCTest UI tests passed | Pass |
| Swift concurrency | Swift 6 complete strict checking | Project build settings | Configured |
| Accessibility | Labels, keyboard flow, Dynamic Type, VoiceOver states | Code review and UI checks | In review |
| Security | Keychain, HTTPS, sandbox, no secret logging | Security tests and local sandbox launch verification passed | Pass for source build |
| Privacy | No analytics, tracking, or live AI | Manifest copied into macOS and iOS app bundles | Pass for source build |
| App icons | Asset catalogue validates on both platforms | Debug and Release platform builds passed | Pass |
| iOS distribution | App Store package signs and processes | Build 2 uses Apple Distribution, App Store provisioning, and is Ready to Submit | Pass |
| macOS distribution | Sandboxed universal archive validates locally | Build 2 archive passed local signing, hardened-runtime, icon, and privacy checks; export and upload pending | In progress |
| Real devices | Supported-device behaviour | TestFlight matrix | Not started |

## Required release test matrix

| Platform | Minimum | Additional coverage | Status |
|---|---|---|---|
| iPhone | iOS 18 | Current supported iOS, small and large Dynamic Type | Not started |
| iPad | iPadOS 18 | Compact and regular layouts, keyboard navigation | Not started |
| Mac | macOS 15 | Apple silicon, keyboard shortcuts, window restoration | Local development only |
| Mac | macOS 15 | Intel where available | Not started |

## Automated verification evidence

The build 2 source and distribution validation used Xcode 27.0 beta 6, build
27A5252f, with Apple Swift 6.4.

| Command | Result |
|---|---|
| `xcodegen generate --spec project.yml` | Passed |
| `./script/ci.sh` | macOS Debug build, generic iOS Simulator Debug build, and 61 unit tests in 8 suites passed |
| Signed iOS Release archive and local App Store export | Passed, build 2 signed with Apple Distribution and App Store provisioning |
| Signed macOS Release archive | Passed, universal archive with App Sandbox, hardened runtime, icon, and privacy manifest |
| App Store Connect upload | Build 2 processed and is Ready to Submit |

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
- [x] Build 2 export-compliance decision is recorded as
      `ITSAppUsesNonExemptEncryption = false`.
- [ ] Demo environment contains invented data and no production integration.
- [ ] App Review credentials are entered only in private App Store Connect fields.

## Release risks

The active risks and responses are maintained in
`docs/governance/RISK_REGISTER.md`. The highest release blockers are incomplete
Milestone 2 functionality, missing physical-device evidence, missing review-only
server access, pending privacy answers, the unverified macOS upload path, and the
current Apple documentation ambiguity around a single multiplatform target for
universal purchase.

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
