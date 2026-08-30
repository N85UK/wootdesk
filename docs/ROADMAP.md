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

These are excluded on purpose, not overlooked, and no partial implementation of
any of them is present in the code:

| Excluded | Planned for |
|---|---|
| Message history, replies, private notes, attachments | Milestone 2 |
| Assignment, labels, teams, status changes, canned responses | Milestone 2 |
| ActionCable or any other real-time update mechanism | Milestone 3 |
| Push notifications and background refresh | Milestone 3 |
| Any live OpenAI call, and the AI Gateway itself | Milestone 4 |
| Offline caching and an outgoing mutation queue | Milestone 5 |
| Signed archives, TestFlight distribution, and App Review submission | Release work after Milestone 2 |
| A full brand system beyond the original app icon | Milestone 5 |
| Analytics or telemetry sent off the device | Not planned |

---

## Milestone 2: Conversation Detail, Message History & Replies (Next)
- [ ] Interactive message timeline view (`GET /api/v1/accounts/{account_id}/conversations/{id}/messages`).
- [ ] Rich markdown and HTML message rendering.
- [ ] Reply composer supporting agent replies and private internal notes (`POST .../messages`).
- [ ] Multipart file and image attachment uploading (`multipart/form-data`).
- [ ] Conversation status management (Resolve, Reopen, Snooze, Pending).
- [ ] Agent assignment and team reassignment.
- [ ] Custom labels and priority triage.

### Distribution Gate After Milestone 2

- [ ] Validate organisation-signed iOS and macOS archives.
- [ ] Complete a dedicated invented-data App Review environment.
- [ ] Run physical-device and Mac TestFlight acceptance.
- [ ] Approve final metadata, privacy, export compliance, age rating, and screenshots.
- [ ] Record an explicit product, security, and release Go decision before App Review submission.

---

## Milestone 3: Real-Time Updates & Push Notifications
- [ ] WebSocket connection via ActionCable (`RoomChannel`) using `pubsub_token`.
- [ ] Low-latency inbox invalidation on new message events.
- [ ] Reconnection state machine with automatic REST reconciliation.
- [ ] Push relay design and APNs integration.

---

## Milestone 4: WootDesk AI Gateway & Deep Cited Research
- [ ] Self-hostable, authenticated WootDesk AI Gateway service.
- [ ] Conversation summarisation and action item extraction.
- [ ] Intelligent draft replies with tone and style adjustments.
- [ ] Cited deep research workflow based on conversation briefs and web sources via OpenAI Responses API.
- [ ] Granular user privacy controls and message redaction previews before submission.

---

## Milestone 5: Offline-First Synchronisation & Enterprise
- [ ] SwiftData persistent caching for conversations and messages.
- [ ] Outgoing mutation queue with background sync.
- [ ] Organisation-wide configuration profiles via MDM (`.mobileconfig`).
- [ ] Optional Developer ID packaging and notarisation for distribution outside the Mac App Store.
