# WootDesk Agent & Automation Guide

This document provides context, design principles, and operational rules for AI coding assistants and autonomous engineering agents working on WootDesk.

---

## Core Tenets

1. **Swift 6 & Strict Concurrency:**
   All code must compile under Swift 6 with strict concurrency checking enabled (`SWIFT_STRICT_CONCURRENCY: complete`). Avoid global mutable state, un-isolated closures, and non-Sendable shared state.

2. **Apple Native Frameworks First:**
   Prefer SwiftUI, Foundation, Security (Keychain), OSLog, and modern Observation (`@Observable`). Avoid introducing third-party dependencies unless explicitly required by the user.

3. **Multiplatform Parity:**
   Target macOS 15.0+ and iOS/iPadOS 18.0+ simultaneously from a shared multiplatform app target. Respect native platform interaction models:
   - macOS: Native windowing, sidebar navigation, keyboard shortcuts, standard menu bar items, compact list formatting.
   - iOS/iPadOS: Touch-first ergonomics, pull-to-refresh, adaptive sheet presentations, Dynamic Type.

4. **Security & Privacy Boundaries:**
   - Secrets belong solely in Apple Keychain.
   - Non-secret metadata is stored in `Application Support/WootDesk/`.
   - Never log tokens, passwords, authorisation headers, or full message bodies.
   - AI features must route through the authenticated WootDesk AI Gateway rather than shipping direct OpenAI keys in the client app.

5. **Language & Conventions:**
   - Use British English in documentation and user-facing copy (e.g., *Authorisation*, *Normalise*, *Colour*, *Organise*).
   - Do not use em dashes or en dashes in any text, including code comments and commit messages. Use commas, colons, parentheses, or separate sentences.
   - Write clear, focused unit tests covering models, decoders, persistence, and state transitions.

6. **The Xcode Project Is Generated:**
   `WootDesk.xcodeproj` is produced by XcodeGen from `project.yml`. Add targets, build settings, and entitlements in `project.yml` and run `xcodegen generate`. Editing the generated project or the entitlements file directly will be silently overwritten on the next generation.

7. **Never Fake a Result:**
   Do not add code, previews, or tests that imply a connection succeeded, data was loaded, or a check passed when it did not. A response the app cannot understand is an error, never an empty list. Previews must reach their named state through the real code path, using `StubChatwootAPI`, rather than rendering a static imitation of it.

8. **Never Commit Real Data:**
   No access token, real server address, customer message, or personal detail belongs in source, fixtures, logs, screenshots, documentation, or CI output. Fixtures use invented values and `example.com` / `example.invalid` hosts.

---

## Key File Locations

- `WootDesk/App/`: Root application lifecycle, environment injection, and top-level model.
- `WootDesk/Core/API/`: Chatwoot Application API client, request builder, error mapping, and DTOs.
- `WootDesk/Core/Models/`: App-facing domain models.
- `WootDesk/Core/Persistence/`: Atomically written local profile repository.
- `WootDesk/Core/Security/`: Apple Keychain credential store, plus the in-memory store used by tests and previews.
- `WootDesk/Core/Preview/`: Invented sample data for previews and tests. Never real data.
- `WootDesk/Features/`: Feature-scoped views and view state managers.
- `WootDesk/AI/`: AIProvider protocols, research data types, and mock providers.
- `script/`: Local build and CI validation scripts (`build_and_run.sh`, `ci.sh`).
- `docs/`: Product specifications, architecture documents, and architectural decision records.
