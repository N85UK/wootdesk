# WootDesk Development Roadmap

This roadmap outlines the milestones for WootDesk development from initial foundation to full production release.

---

## Milestone 1: Foundation Vertical Slice (Completed)
- [x] Native multiplatform Xcode project (macOS 15.0+, iOS 18.0+) with Swift 6 strict concurrency.
- [x] Connection setup flow with URL normalisation and HTTPS enforcement.
- [x] Live validation against `GET /api/v1/profile`.
- [x] Multi-account picker and auto-selection for single-account profiles.
- [x] Apple Keychain token persistence (`kSecAttrAccessibleAfterFirstUnlockThisDeviceOnly`).
- [x] Atomic Application Support JSON storage for profile metadata.
- [x] Multi-server switching, edit and revalidation, and transactional destructive removal.
- [x] Real conversation list browser (`GET /api/v1/accounts/{id}/conversations`) with status filters, paging, and local search.
- [x] Conversation detail placeholder showing only data the list endpoint returned.
- [x] macOS App Sandbox with outbound network access only.
- [x] Abstraction boundary for future AI Gateway integration (`AIProvider`).
- [x] Local CI script and GitHub Actions workflow.
- [x] Original iOS, iPadOS, and macOS app icon catalogue.
- [x] Privacy manifest, public privacy policy, App Store preparation guide, and release governance documents.

### Deliberately Not in Milestone 1

These were excluded from the Milestone 1 release scope. Some are now being
implemented as part of Milestone 2:

| Excluded | Planned for |
|---|---|
| Message history, replies, private notes, attachments | Milestone 2, source implementation complete, live acceptance pending |
| Assignment, labels, teams, status changes, canned responses | Milestone 2 |
| ActionCable or any other real-time update mechanism | Milestone 3 |
| Push notifications and background refresh | Milestone 3 |
| Any live OpenAI call, and the AI Gateway itself | Milestone 4 |
| Offline caching and an outgoing mutation queue | Milestone 5 |
| Signed archives, TestFlight distribution, and App Review submission | Release work after Milestone 2 |
| A full brand system beyond the original app icon | Milestone 5 |
| Analytics or telemetry sent off the device | Not planned |

---

## Milestone 2: Conversation Detail, Message History & Replies (In Progress)
- [x] Interactive paginated message timeline view (`GET /api/v1/accounts/{account_id}/conversations/{id}/messages`).
- [x] Safe processed-HTML conversion and inline Markdown presentation without active embedded links.
- [x] Plain-text reply composer supporting agent replies and private internal notes (`POST .../messages`).
- [x] In-memory draft retention after recoverable send failures and draft isolation between conversations and server profiles.
- [x] Mocked API, decoding, feature-state, and launch UI coverage for message history and replies.
- [x] Opt-in compatibility harness for supported Chatwoot versions, disabled in normal CI.
- [ ] Dedicated invented-data Chatwoot compatibility and acceptance run.
- [x] Multipart file and image attachment uploading (`multipart/form-data`).
- [x] Safe received-attachment metadata, explicit remote-open confirmation, and no automatic remote fetch.
- [x] Account-specific agent availability selector for Online, Busy, and Offline (`POST /api/v1/profile/availability`).
- [ ] Conversation status management (Resolve, Reopen, Snooze, Pending).
- [ ] Agent assignment and team reassignment.
- [ ] Custom labels and priority triage.

### Distribution Gate After Milestone 2

- [x] Create and locally validate organisation-signed iOS and universal macOS build 3 archives.
- [x] Export the iOS build 3 App Store package locally.
- [x] Create the required Mac Installer Distribution certificate and Mac App Store profile, then export the macOS package.
- [ ] Complete a dedicated invented-data App Review environment.
- [ ] Run physical-device and Mac TestFlight acceptance.
- [ ] Approve final metadata, privacy, export compliance, age rating, and screenshots.
- [ ] Record an explicit product, security, and release Go decision before App Review submission.

---

## Milestone 3: Real-Time Updates & Push Notifications
- [ ] WebSocket connection via ActionCable (`RoomChannel`) using `pubsub_token`.
- [ ] Low-latency inbox invalidation on new message events.
- [ ] Reconnection state machine with automatic REST reconciliation.
- [x] Native permission, local verification, and APNs registration lifecycle.
- [x] iOS and macOS APNs entitlement templates with environment separation.
- [x] Document the direct APNs provider boundary and reject incompatible FCM registration.
- [x] Implement the authenticated, self-hostable WootDesk Push Gateway source and deterministic test harness.
- [x] Add per-profile gateway enrolment, APNs token rotation, safe deletion, and opaque notification routing.
- [ ] Deploy the gateway behind an approved HTTPS proxy and secret store.
- [ ] Replace or approve the account-wide recipient policy with a reviewed per-agent authorisation policy.
- [ ] Complete physical-device delivery acceptance with invented Chatwoot data.

---

## Milestone 4: WootDesk AI Gateway & Deep Cited Research
- [ ] Self-hostable, authenticated WootDesk AI Gateway service.
- [ ] Conversation summarisation and action item extraction.
- [ ] Intelligent draft replies with tone and style adjustments.
- [ ] Cited deep research workflow based on conversation briefs and web sources via OpenAI Responses API.
- [ ] Granular user privacy controls and message redaction previews before submission.

---

## Milestone 5: Offline-First Synchronisation & Enterprise

Bounded offline resilience is delivered under N85-16. It deliberately stops
short of a synchronising cache: WootDesk stores only what the agent has already
been shown, and represents an unconfirmed send rather than replaying it.

- [x] Protected per-profile storage for unsent drafts, surviving app close (N85-16 AC1).
- [x] Per-profile cached message pages, shown and labelled as a saved copy when a refresh fails (N85-16 AC2).
- [x] Unconfirmed sends recorded and warned about, instead of being reported as sent or simply failed (N85-16 AC3).
- [x] Executable attachment types refused before the file is read, and cancelled selections explained (N85-16 AC4).
- [x] Draft, cache and unconfirmed-send deletion when a server profile is removed (N85-16 AC5).
- [x] Offline storage optional, with an off switch that also purges what was stored (N85-16 AC6).
- [ ] SwiftData persistent caching for conversations and messages.
- [ ] Outgoing mutation queue with background sync.
- [ ] Organisation-wide configuration profiles via MDM (`.mobileconfig`).
- [ ] Optional Developer ID packaging and notarisation for distribution outside the Mac App Store.

### Deliberately not implemented for N85-16

An automatic retry queue was not built. Chatwoot's message endpoint has no
idempotency key, so a replayed request can post the same reply twice. Recording
the uncertainty and asking the agent is the only behaviour that cannot
duplicate a customer-visible message. This is the reason AC3 is phrased as
representation rather than recovery.
