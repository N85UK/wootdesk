# WootDesk Release Readiness

Document ID: `WOOT-REL-001`

Status: Blocked for public App Store release

Owner: N85 Dev

Last reviewed: 30 August 2026

## Release details

| Field | Detail |
|---|---|
| Proposed release | 1.0.0 (1) |
| Release channel | TestFlight first, then App Store after approval |
| Platforms | iOS, iPadOS, macOS |
| Release date | To confirm |
| Repository branch | `feat/foundation-chatwoot-connection` |
| Public service | Not released |

## Current decision

Public App Store release: **No-go**

The foundation connection and conversation-list slice works, but message
history and replies are not implemented. A signed TestFlight candidate may be
prepared after the account, signing, privacy, demo, and archive gates below are
complete.

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
| GO-004 | iOS and macOS archives validate | Xcode Organizer validation reports | Not started |
| GO-005 | Physical-device TestFlight checks pass | Test matrix and tester sign-off | Not started |
| GO-006 | App Store metadata and screenshots are approved | Final platform metadata | Not started |
| GO-007 | Privacy and export-compliance answers are approved | Account Holder record | Not started |
| GO-008 | Dedicated App Review server and account are ready | Private review runbook | Not started |
| GO-009 | App Store Connect agreements and roles are ready | Account Holder evidence | Not started |
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
| Real devices | Supported-device behaviour | TestFlight matrix | Not started |

## Required release test matrix

| Platform | Minimum | Additional coverage | Status |
|---|---|---|---|
| iPhone | iOS 18 | Current supported iOS, small and large Dynamic Type | Not started |
| iPad | iPadOS 18 | Compact and regular layouts, keyboard navigation | Not started |
| Mac | macOS 15 | Apple silicon, keyboard shortcuts, window restoration | Local development only |
| Mac | macOS 15 | Intel where available | Not started |

## Automated verification evidence

The final source validation used the only installed Xcode toolchain, Xcode 27.0
build 27A5194q with Apple Swift 6.4.

| Command | Result |
|---|---|
| `xcodegen generate --spec project.yml` | Passed |
| `./script/ci.sh --with-ui-tests` | macOS Debug build, iOS Simulator Debug build, 61 unit tests, and 2 UI tests passed |
| macOS Release build with signing disabled | Passed |
| iOS Simulator Release build with signing disabled | Passed |
| `./script/build_and_run.sh --verify` | Built, launched, remained running, and App Sandbox entitlement was present |

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
- [ ] Export-compliance decision is recorded by the Account Holder.
- [ ] Demo environment contains invented data and no production integration.
- [ ] App Review credentials are entered only in private App Store Connect fields.

## Release risks

The active risks and responses are maintained in
`docs/governance/RISK_REGISTER.md`. The highest release blockers are incomplete
Milestone 2 functionality, unsigned archives, missing physical-device evidence,
missing review-only server access, and the current Apple documentation ambiguity
around a single multiplatform target for universal purchase.

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
