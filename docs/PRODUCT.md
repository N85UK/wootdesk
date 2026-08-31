# WootDesk Product Specification

## Executive Summary

WootDesk is an independent native Apple client for [Chatwoot](https://www.chatwoot.com), the open-source customer engagement platform. It enables customer support agents, engineers, and team leaders to access customer conversations across macOS, iOS, and iPadOS with native Apple platform integration.

---

## Target Audience & Personas

1. **Self-Hosted Team Lead / DevOps Engineer:**
   - Runs their own Chatwoot instance on internal infrastructure or Kubernetes.
   - Values strict data privacy, Keychain-backed credential storage, and lack of external tracking telemetry.
   - Needs seamless multi-instance management to monitor development, staging, and production inboxes.

2. **Customer Support Agent (macOS User):**
   - Spends hours handling incoming queries every day.
   - Requires snappy keyboard shortcuts (Cmd+R, Cmd+Shift+N), dense split-view navigation, fast search, and native notifications.
   - Frustrated by heavy Electron/browser-based interfaces.

3. **On-Call Support Engineer (iOS/iPadOS User):**
   - Needs to triage urgent conversations, review customer context, and draft replies while away from their desk.
   - Requires clean mobile layouts, Dynamic Type support, and pull-to-refresh.

---

## Core Product Pillars

1. **Native Apple Experience:**
   - Built purely in Swift 6 and SwiftUI without WebView or Electron wrappers.
   - Uses standard navigation, controls, accessibility behaviour, and platform interaction patterns.

2. **System Security & Privacy:**
   - Credentials stored solely in Apple Keychain.
   - Transport encryption enforced via TLS/HTTPS.
   - No analytics or remote telemetry. Network data is sent only to the selected Chatwoot server in this milestone.

3. **Independent & Extensible Architecture:**
   - Works with any self-hosted or cloud Chatwoot instance supporting the Application API.
   - Designed for future integration with a privacy-preserving WootDesk AI Gateway.

---

## Release Scope & Milestones

- **Milestone 1 (Foundation):** Multiplatform app shell, connection setup, profile validation, multi-account selection, Keychain token storage, conversation listing, and filtering.
- **Milestone 2 (Conversation Detail & Replies):** Interactive paginated timeline, safe agent reply composer, private notes, richer message rendering, and file attachments.
- **Milestone 3 (Real-Time Synchronisation):** ActionCable WebSocket connection, low-latency invalidation, push relay integration.
- **Milestone 4 (AI Intelligence & Deep Research):** Privacy-first WootDesk AI Gateway integration for summaries, reply drafting, and cited deep research.
- **Milestone 5 (Offline First & Enterprise):** SwiftData persistent caching, offline mutation queue, and organisation profile policies.

## Current Release Position

Milestone 1 is an early-development foundation, not a production or App Store
release. The Milestone 2 source now adds paginated message history, plain-text
replies, private notes, safe inline formatting, attachment upload, and
privacy-first attachment presentation. Milestone 3 now includes the native
notification permission and APNs registration foundation, but remote Chatwoot
delivery is not active until the authenticated push provider is implemented.
Public distribution remains blocked until this work passes dedicated
invented-data server and TestFlight acceptance,
the remaining distribution and listing gates close, and the named release
owners record an explicit Go decision.

The original WootDesk app icon, privacy manifest, draft listing metadata, and
submission runbook prepare the repository for that work without claiming an
uploaded build or Apple approval.
