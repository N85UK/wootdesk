# Delivery Decision Log

Document ID: `WOOT-DEC-INDEX-001`

Last reviewed: 31 August 2026

| ID | Decision | Status | Evidence |
|---|---|---|---|
| DEC-001 | Build one native SwiftUI multiplatform application | Accepted | `docs/decisions/0001-native-multiplatform-app.md` |
| DEC-002 | Keep tokens in Keychain and profile metadata in Application Support | Accepted | `docs/decisions/0002-keychain-and-local-profile-storage.md` |
| DEC-003 | Prepare one App Store Connect product with iOS, iPadOS, and macOS versions | Accepted for release preparation | `docs/decisions/0003-app-store-distribution-and-branding.md` |
| DEC-004 | Use an original generic inbox and conversation icon with distinct platform treatments | Accepted | `docs/BRANDING.md` |
| DEC-005 | Use automatic signing without a committed development-team identifier | Accepted | `project.yml` and App Store submission guide |
| DEC-006 | TestFlight precedes public distribution, and public release remains blocked until Milestone 2 | Accepted | `docs/RELEASE_READINESS.md` |
| DEC-007 | Use native APNs registration and a separate authenticated push provider instead of sending APNs tokens to Chatwoot's FCM endpoint | Client and provider source accepted, deployment pending | `docs/decisions/0004-native-apns-and-push-provider-boundary.md` |

Account-level actions such as agreement acceptance, upload, TestFlight release,
and App Review submission require a separate explicit owner decision. This log
does not grant that approval.
