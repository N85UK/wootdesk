# WootDesk

WootDesk is an independent, native Apple-platform client for [Chatwoot](https://www.chatwoot.com) customer support platforms. It is designed to run seamlessly across macOS, iOS, and iPadOS, connecting directly to self-hosted installations and cloud instances that you control.

> [!IMPORTANT]
> **Independent Project Notice:** WootDesk is an independent open-source client application. It is not affiliated with, maintained by, or endorsed by Chatwoot. The Chatwoot name and marks belong to their respective owners.

---

## Early Development Status

WootDesk is in active early development. Milestone 1 established the secure
connection and conversation-list vertical slice. The repository now includes
the Milestone 2 source implementation for reading messages, sending replies and
private notes, and handling attachments. It is not production-ready, available
on the Apple App Store, or intended for general rollout.

### Current Functionality
- **Multiplatform Support:** Native SwiftUI architecture running on macOS 15.0+ and iOS 18.0+.
- **Secure Server Setup:** Connect to any Chatwoot installation using standard Application API personal access tokens.
- **Connection Validation:** Live endpoint validation via `GET /api/v1/profile` before saving.
- **Account Selection:** Automatic single-account detection and interactive multi-account picker when a user profile belongs to several accounts.
- **Keychain-Only Credentials:** Access tokens are stored solely in Apple Keychain. iOS and release builds use the device-only protection class `kSecAttrAccessibleAfterFirstUnlockThisDeviceOnly`. Ad-hoc macOS Debug builds use the default local Keychain because the data-protection Keychain requires an authorised application identifier. Tokens are never written to application storage in plain text or marked as synchronisable.
- **Resilient Profile Management:** Non-secret profile metadata persists atomically in Application Support with automatic recovery from corrupted configurations.
- **Multi-Server Management:** Add, switch, edit and revalidate, or safely remove saved Chatwoot installations.
- **Agent Availability:** View and set Online, Busy, or Offline for the selected account from native settings on every platform, with a quick selector in the macOS sidebar.
- **Real Conversation Browser:** Live conversation listing with status filtering (Open, Pending, Resolved, Snoozed, All), paging, unread counts, priority indicators, and local search.
- **Message Timeline:** Load the newest Chatwoot messages for a selected conversation and page backwards through older messages.
- **Replies and Private Notes:** Send plain-text agent replies or private notes through the Chatwoot Application API. Drafts remain in memory only and are cleared only after the server confirms creation.
- **Safe Message Presentation:** Convert processed HTML to readable text, apply inline Markdown formatting without activating embedded links, and tolerate unknown message fields.
- **Attachment Handling:** Upload selected files as documented `multipart/form-data`, retain selections in memory after recoverable failures, and show received attachment metadata without fetching remote content automatically. Opening a remote attachment requires an explicit confirmation.
- **Adaptive Navigation:** Mac and iPad present workspace navigation, the conversation list, and the selected conversation as three adjacent columns, collapsing to a single column without losing the selected workspace or conversation. iPhone uses a tab layout. The status filter becomes a menu at accessibility text sizes so no option is clipped.
- **Conversation Triage:** Set a conversation to open, pending or resolved, snooze it until a chosen future time, set or clear its priority, assign it to an agent or team, and add or remove labels. Every change is confirmed by reading the conversation back from Chatwoot, so a value is shown only once the server reports it. Label changes read the current server set immediately before writing, so a label another agent added is never discarded.
- **Notification Routing:** Opening a notification activates the saved profile it belongs to, clears the previous profile's data, removes any search or status filter that would hide the conversation, and fetches the conversation directly when it is outside the loaded page. A conversation that cannot be opened is explained rather than replaced with another one.
- **Server Isolation:** Conversation and message state is cleared whenever the active server profile or selected conversation changes.
- **Sandboxed on macOS:** The Mac app runs in the App Sandbox with outbound network access and read-only access to files the user explicitly selects for upload.
- **Original App Identity:** Includes distinct iOS, iPadOS, and macOS app icon treatments based on a generic inbox and conversation symbol, without Chatwoot branding.
- **Native Notification Client:** Provides explicit notification permission, APNs device registration, foreground presentation, safe notification routing, an invented local test alert, and per-profile gateway enrolment and removal. Gateway credentials are stored in a separate Apple Keychain service.
- **Self-Hostable Push Gateway Foundation:** Includes a dependency-free Node.js service that authenticates device mutations, encrypts APNs tokens at rest, accepts a narrow Chatwoot webhook policy, and sends generic APNs alerts. It is implemented and tested but not deployed, provisioned with Apple credentials, or approved for public operation.
- **Strict Concurrency:** Built entirely in Swift 6 language mode with complete strict concurrency checking.

### Planned Functionality (Upcoming Milestones)
- **Milestone 2 Completion:** Dedicated live-server acceptance for the message and triage workflows.
- **Milestone 3:** Deploy and accept the authenticated push gateway, add a reviewed per-agent recipient policy, complete signed physical-device notification testing, and add WebSocket invalidation via ActionCable (`RoomChannel`).
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
3. **App Sandbox:** The macOS project requests outbound network access and read-only access to files selected through the system picker. It requests no broad file access.
4. **No Embedded Third-Party Keys:** WootDesk contains no hardcoded API keys, tracking SDKs, or analytics.
5. **Isolated AI Gateway Architecture:** Planned AI features would communicate with a user-controlled, authenticated gateway rather than embedding an OpenAI key in the client. No AI request is made by the app today.
6. **Explicit Push Boundary:** APNs device tokens remain in app memory, are never logged or sent to Chatwoot, and leave the device only after deliberate enrolment with an authenticated WootDesk Push Gateway. The gateway credential is stored in Apple Keychain. The gateway never receives a Chatwoot personal access token and its encrypted registration store contains no message body or customer identity.

See [SECURITY.md](SECURITY.md) for the full policy.
See [PRIVACY.md](PRIVACY.md) for the current data-processing disclosure.

---

## Building and Testing

### Prerequisites
- macOS 15.0 or later
- Xcode 16.0 or later.
- Node.js 22 or later for the push gateway checks. The Apple app has no Node.js runtime dependency.
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

`script/ci.sh` runs the gateway tests and dependency policy, builds the macOS
and iOS Simulator destinations, and runs the Swift unit tests. It needs no
Chatwoot server, Apple service, credentials, or signing identity.

`script/build_and_run.sh` refreshes the project-local Launch Services entries
before launching, so older Xcode build products cannot supply a stale Dock icon.

The macOS UI tests are excluded by default. They use an ad-hoc signed runner and
need Apple Automation Mode to be configured on the host. The script checks that
state before starting and closes any running WootDesk instance so the test build
owns the app launch:

```bash
./script/ci.sh --with-ui-tests
```

See [the macOS UI-test host guide](docs/MACOS_UI_TESTING.md) for the one-time
administrator setting and its security implications.

Live Chatwoot compatibility tests are opt-in and must use a dedicated server
containing invented data only. See
[the compatibility runbook](docs/CHATWOOT_COMPATIBILITY.md). The normal CI suite
never contacts a live server.

---

## Documentation

Detailed architectural and design documentation is available in [`docs/`](docs/):
- [Delivery Index and Current Gates](docs/DELIVERY.md)
- [Product Vision and Scope](docs/PRODUCT.md)
- [System Architecture and Data Flow](docs/ARCHITECTURE.md)
- [Development Roadmap](docs/ROADMAP.md)
- [Push Notification Architecture and Activation](docs/PUSH_NOTIFICATIONS.md)
- [Push Gateway Deployment and API Contract](Gateway/README.md)
- [App Store Submission Guide](docs/APP_STORE_SUBMISSION.md)
- [Draft App Store Metadata](docs/APP_STORE_METADATA.md)
- [Release Readiness](docs/RELEASE_READINESS.md)
- [Chatwoot Compatibility Runbook](docs/CHATWOOT_COMPATIBILITY.md)
- [TestFlight Acceptance Plan](docs/TESTFLIGHT_TEST_PLAN.md)
- [macOS UI Test Host Preparation](docs/MACOS_UI_TESTING.md)
- [Brand and App Icon](docs/BRANDING.md)
- [Requirement Traceability](docs/governance/REQUIREMENT_TRACEABILITY.md)
- [Delivery Risk Register](docs/governance/RISK_REGISTER.md)
- [Delivery Decision Log](docs/governance/DECISION_LOG.md)
- [AI Gateway and Deep Research Specification](docs/OPENAI_INTEGRATION.md)
- [ADR 0001: Native Multiplatform SwiftUI App](docs/decisions/0001-native-multiplatform-app.md)
- [ADR 0002: Keychain & Local Profile Storage](docs/decisions/0002-keychain-and-local-profile-storage.md)
- [ADR 0003: App Store Distribution and Independent Branding](docs/decisions/0003-app-store-distribution-and-branding.md)
- [ADR 0004: Native APNs Client and Separate Push Provider](docs/decisions/0004-native-apns-and-push-provider-boundary.md)

## App Store Position

The App Store Connect record and historical build 3 signing evidence are in place. iOS build 2 has
completed processing and is marked Ready to Submit in TestFlight. Build 1 is
superseded and remains marked Missing Compliance. No testers have been added,
and no build has been submitted for App Review. Fresh iOS and universal macOS
build 3 archives pass local validation, and both platform packages export
locally. Neither build 3 candidate has been uploaded. The notification changes
start build 4 source and have not been signed, archived, or uploaded. The
current command-line Keychain inventory contains no valid distribution identity
or downloaded provisioning profile, so fresh distribution work is blocked
until the approved signing material and push-capable profiles are available.

The current uploaded iOS build 2 predates the Milestone 2 and notification
source changes. Public submission remains a no-go until live acceptance,
push gateway deployment and recipient-policy approval, refreshed push-capable signing profiles,
privacy review, review access, physical-device testing, and explicit owner
approvals are complete.

Follow [the App Store submission guide](docs/APP_STORE_SUBMISSION.md) for the
account, signing, metadata, archive, TestFlight, and review sequence. Account
agreements, signing changes, future build uploads, tester access, and App Review
submission must be completed by an authorised Apple Developer account holder.

---

## Community and Legal

WootDesk is developed in public. Before participating, please review:

- [Code of Conduct](CODE_OF_CONDUCT.md), the behaviour expected in project spaces.
- [Contributing](CONTRIBUTING.md), the development workflow and validation requirements.
- [MIT Licence](LICENSE), the permissions and conditions for using this software.
- [Security Policy](SECURITY.md), including private vulnerability reporting.

Contributions, bug reports, and focused feature proposals are welcome. Security
reports and conduct concerns that contain private information must not be filed
as public issues.

WootDesk is an independent project. Chatwoot is a trademark of its respective
owners, and this project is not affiliated with or endorsed by them.
