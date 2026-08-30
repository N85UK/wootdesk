# WootDesk

WootDesk is an independent, native Apple-platform client for [Chatwoot](https://www.chatwoot.com) customer support platforms. It is designed to run seamlessly across macOS, iOS, and iPadOS, connecting directly to self-hosted installations and cloud instances that you control.

> [!IMPORTANT]
> **Independent Project Notice:** WootDesk is an independent open-source client application. It is not affiliated with, maintained by, or endorsed by Chatwoot. The Chatwoot name and marks belong to their respective owners.

---

## Early Development Status

WootDesk is in active early development. This repository represents the **Foundation Vertical Slice (Milestone 1)**. It provides the first complete connection and conversation-list journey, but it is not production-ready, available on the Apple App Store, or intended for general rollout.

### Current Functionality (Milestone 1)
- **Multiplatform Support:** Native SwiftUI architecture running on macOS 15.0+ and iOS 18.0+.
- **Secure Server Setup:** Connect to any Chatwoot installation using standard Application API personal access tokens.
- **Connection Validation:** Live endpoint validation via `GET /api/v1/profile` before saving.
- **Account Selection:** Automatic single-account detection and interactive multi-account picker when a user profile belongs to several accounts.
- **Keychain-Only Credentials:** Access tokens are stored solely in Apple Keychain. iOS and release builds use the device-only protection class `kSecAttrAccessibleAfterFirstUnlockThisDeviceOnly`. Ad-hoc macOS Debug builds use the default local Keychain because the data-protection Keychain requires an authorised application identifier. Tokens are never written to application storage in plain text or marked as synchronisable.
- **Resilient Profile Management:** Non-secret profile metadata persists atomically in Application Support with automatic recovery from corrupted configurations.
- **Multi-Server Management:** Add, switch, edit and revalidate, or safely remove saved Chatwoot installations.
- **Real Conversation Browser:** Live conversation listing with status filtering (Open, Pending, Resolved, Snoozed, All), paging, unread counts, priority indicators, local search, and a detail placeholder.
- **Sandboxed on macOS:** The Mac app runs in the App Sandbox with outbound network access only.
- **Original App Identity:** Includes distinct iOS, iPadOS, and macOS app icon treatments based on a generic inbox and conversation symbol, without Chatwoot branding.
- **Strict Concurrency:** Built entirely in Swift 6 language mode with complete strict concurrency checking.

### Planned Functionality (Upcoming Milestones)
- **Milestone 2:** Interactive message history, reply composer, private notes, and attachment viewer.
- **Milestone 3:** Real-time push and WebSocket invalidation via ActionCable (`RoomChannel`).
- **Milestone 4:** Privacy-preserving WootDesk AI Gateway integration for conversation summarisation, smart draft replies, and cited deep research.
- **Milestone 5:** Offline-first caching, outgoing mutation queue, and multi-tenant enterprise features.

---

## Platform Requirements

| Platform | Minimum OS Version |
|---|---|
| **macOS** | macOS 15.0 or later |
| **iOS / iPadOS** | iOS 18.0 / iPadOS 18.0 or later |

---

## Security Model

WootDesk follows these security boundaries:
1. **No Secret Persisted in Plain Text:** Personal access tokens exist only in the Apple Keychain, keyed by the server profile's UUID, and are deleted with the profile.
2. **Mandatory Transport Layer Security:** HTTPS is enforced for all production server connections. Plain HTTP is restricted to `localhost` in debug builds. System certificate trust is used unmodified; there is no trust-all delegate and no global App Transport Security exception.
3. **App Sandbox:** The macOS project entitlement file requests the App Sandbox and outbound network client capabilities only.
4. **No Embedded Third-Party Keys:** WootDesk contains no hardcoded API keys, tracking SDKs, or analytics.
5. **Isolated AI Gateway Architecture:** Planned AI features would communicate with a user-controlled, authenticated gateway rather than embedding an OpenAI key in the client. No AI request is made by the app today.

See [SECURITY.md](SECURITY.md) for the full policy.
See [PRIVACY.md](PRIVACY.md) for the current data-processing disclosure.

---

## Building and Testing

### Prerequisites
- macOS 15.0 or later
- Xcode 16.0 or later.
- [XcodeGen](https://github.com/yonaskolb/XcodeGen) (`brew install xcodegen`) to regenerate `WootDesk.xcodeproj` from `project.yml`. The generated project is committed, so a clean clone builds without it.

### Quick Start
```bash
# 1. Clone repository
git clone https://github.com/N85UK/wootdesk.git
cd wootdesk

# 2. Generate Xcode project
xcodegen generate

# 3. Run the macOS and iOS Simulator builds and unit tests
./script/ci.sh

# 4. Build and run macOS app locally, then verify it stays running
./script/build_and_run.sh --verify
```

`script/ci.sh` builds the macOS and iOS Simulator destinations and runs the unit
tests. It needs no Chatwoot server, credentials, or signing identity.

The macOS UI tests are excluded by default because an unsigned UI-test runner is
killed by macOS before it can connect. Run them with ad-hoc signing. The script
closes any running WootDesk instance first so the test build owns the app launch:

```bash
./script/ci.sh --with-ui-tests
```

---

## Documentation

Detailed architectural and design documentation is available in [`docs/`](docs/):
- [Delivery Index and Current Gates](docs/DELIVERY.md)
- [Product Vision and Scope](docs/PRODUCT.md)
- [System Architecture and Data Flow](docs/ARCHITECTURE.md)
- [Development Roadmap](docs/ROADMAP.md)
- [App Store Submission Guide](docs/APP_STORE_SUBMISSION.md)
- [Draft App Store Metadata](docs/APP_STORE_METADATA.md)
- [Release Readiness](docs/RELEASE_READINESS.md)
- [Brand and App Icon](docs/BRANDING.md)
- [Requirement Traceability](docs/governance/REQUIREMENT_TRACEABILITY.md)
- [Delivery Risk Register](docs/governance/RISK_REGISTER.md)
- [Delivery Decision Log](docs/governance/DECISION_LOG.md)
- [AI Gateway and Deep Research Specification](docs/OPENAI_INTEGRATION.md)
- [ADR 0001: Native Multiplatform SwiftUI App](docs/decisions/0001-native-multiplatform-app.md)
- [ADR 0002: Keychain & Local Profile Storage](docs/decisions/0002-keychain-and-local-profile-storage.md)
- [ADR 0003: App Store Distribution and Independent Branding](docs/decisions/0003-app-store-distribution-and-branding.md)

## App Store Position

The repository is prepared for signed archive and TestFlight work, but no App
Store Connect record, uploaded build, or public release is claimed. Public
submission remains a no-go until message history and replies are complete,
platform archives validate, privacy and review information are approved, and
physical-device TestFlight checks pass.

Follow [the App Store submission guide](docs/APP_STORE_SUBMISSION.md) for the
account, signing, metadata, archive, TestFlight, and review sequence. Account
agreements, signing-team selection, build upload, and App Review submission must
be completed by an authorised Apple Developer account holder.

---

## Contributing

Contributions, bug reports, and suggestions are welcome! Please review [CONTRIBUTING.md](CONTRIBUTING.md) and [CODE_OF_CONDUCT.md](CODE_OF_CONDUCT.md) before opening a pull request.

---

## Licence

Licensed under the MIT Licence. See [LICENSE](LICENSE).

WootDesk is an independent project. Chatwoot is a trademark of its respective
owners, and this project is not affiliated with or endorsed by them.
