# Requirement Traceability

Document ID: `WOOT-TRACE-001`

Last reviewed: 30 August 2026

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
| REQ-MSG-001 | Show message history for a selected conversation | Milestone 2 | Not implemented | Blocked |
| REQ-REPLY-001 | Send an agent reply or private note | Milestone 2 | Not implemented | Blocked |

The final release commit must replace any pending verification entry with exact
test, archive, or review evidence. Live server credentials and customer data are
never acceptable traceability evidence.
