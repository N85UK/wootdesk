# Requirement Traceability

Document ID: `WOOT-TRACE-001`

Last reviewed: 31 August 2026

| ID | Requirement | Implementation evidence | Verification evidence | Status |
|---|---|---|---|---|
| REQ-CONN-001 | Add and validate a Chatwoot server through `GET /api/v1/profile` | `AddConnectionView`, `ConnectionViewState`, `ChatwootAPIClient` | API, URL, decoding, and connection-flow tests | Implemented |
| REQ-CONN-002 | Select an account when a profile has several accounts | `AccountPickerView`, profile DTO mapping | Single-account and multi-account decoding tests | Implemented |
| REQ-SEC-001 | Store every token only in Apple Keychain | `KeychainCredentialStore`, profile UUID lookup | Credential fake lifecycle and profile-deletion tests | Implemented |
| REQ-PROFILE-001 | Restore, switch, revalidate, edit, and remove profiles | `AppModel`, `FileServerProfileRepository`, connection views | Persistence, switching, and deletion tests | Implemented |
| REQ-CONV-001 | Load and display a real conversation list | `ConversationListState`, `ConversationListView`, API client | Conversation decoding, request, paging, and state tests | Implemented |
| REQ-ERR-001 | Present clear network, authentication, rate, and decoding errors | `APIError`, feature state error mapping | HTTP, timeout, offline, malformed-response tests | Implemented |
| REQ-AI-001 | Keep AI as an app-side protocol and mock only | `AIProvider`, research models, `MockAIProvider` | Source review and build | Implemented |
| REQ-DIST-001 | Provide valid platform app icons | `AppIcon.appiconset` | Debug and Release asset-catalog validation on both platforms | Verified |
| REQ-PRIV-001 | Disclose current processing and declare no tracking | `PRIVACY.md`, `PrivacyInfo.xcprivacy` | Source and release-binary review | Implemented, release review pending |
| REQ-DIST-002 | Document App Store preparation and release gates | App Store, metadata, branding, and readiness documents | Documentation review | Implemented |
| REQ-MSG-001 | Show message history for a selected conversation | `ConversationDetailState`, `ConversationDetailView`, message DTO mapping, cursor paging | Mocked request, decoding, state, and UI journey tests; dedicated-server acceptance pending | Implemented, release review pending |
| REQ-REPLY-001 | Send an agent reply or private note | `ConversationComposerView`, `ConversationDetailState`, `ChatwootAPIClient.createMessage` | Public and private request-body tests, draft-safety state tests, and UI journey; live acceptance pending | Implemented, release review pending |
| REQ-ATTACH-001 | Upload and present attachments without automatic remote fetch | `ConversationAttachment`, `ConversationAttachmentView`, multipart API client, composer file importer | Multipart request, tolerant decoding, unsafe-URL, state-retention, and platform build tests; live acceptance pending | Implemented, release review pending |
| REQ-MSG-SAFE-001 | Present processed HTML and inline Markdown without activating embedded links | `MessageTextFormatter`, `ConversationMessageRowView` | Formatting and unsafe-link unit tests | Implemented |
| REQ-COMPAT-001 | Provide an opt-in live compatibility harness that normal CI cannot trigger | `ChatwootLiveCompatibilityTests`, `script/live_compatibility.sh`, compatibility runbook | Default test run skips both live cases; script requires two flags before writes | Implemented, matrix execution pending |
| REQ-PUSH-CLIENT-001 | Request notification permission and register with APNs without pretending Chatwoot delivery is active | `PushNotificationState`, `SystemNotificationPermissionClient`, `WootDeskApplicationDelegate`, platform entitlements, notification Settings section | Six permission, registration, and local-verification state tests; macOS and iOS Simulator builds | Implemented, signed-device and provider work pending |
| REQ-PUSH-PROVIDER-001 | Relay new incoming Chatwoot message events to the correct saved profile through APNs | `docs/PUSH_NOTIFICATIONS.md`, ADR 0004 | Gateway, signed entitlements, webhook, physical-device delivery, token rotation, deletion, and cross-profile evidence | Not implemented, release blocker |

The final release commit must replace any pending verification entry with exact
test, archive, or review evidence. Live server credentials and customer data are
never acceptable traceability evidence.
