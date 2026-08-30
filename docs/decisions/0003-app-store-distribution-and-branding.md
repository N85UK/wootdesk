# ADR 0003: App Store Distribution and Independent Branding

Status: Accepted for release preparation

Date: 30 August 2026

## Context

WootDesk targets iOS, iPadOS, and macOS from one SwiftUI target and uses one
portable bundle identifier. Distribution needs platform-correct icons, accurate
privacy information, sandboxed Mac capabilities, and signing that can create
archives without publishing a personal team identifier. The product must also
remain visibly independent from Chatwoot.

Current Apple documentation supports a single multiplatform Xcode target, while
App Store Connect guidance for adding macOS to a universal purchase still
refers to a separate target. Both platform archives therefore need an early
App Store Connect preflight.

## Decision

- Prepare one App Store Connect product record using `dev.n85.wootdesk` for the
  iOS, iPadOS, and macOS versions.
- Retain the shared multiplatform target unless archive validation proves thin
  platform-specific distribution targets are required.
- Use automatic signing, selected locally, without committing
  `DEVELOPMENT_TEAM`.
- Keep the macOS App Sandbox limited to outbound network access.
- Ship an iOS master with an opaque full-bleed square and a macOS set with
  transparent optical padding around a rounded-square icon body.
- Use a generic inbox and conversation symbol. Do not use Chatwoot logos,
  icons, screenshots, or trade dress.
- Include a privacy manifest and public privacy policy, reviewed against every
  release binary.
- Use TestFlight before public submission. Public release remains blocked until
  message history and replies satisfy Milestone 2.

## Consequences

- A release engineer must select the organisation team locally before archive.
- CI remains independent of signing identities by passing signing-disabled
  build overrides.
- The first archive preflight may require a small target-layout change, but not
  a duplicate application architecture.
- App Store metadata, screenshots, demo access, privacy answers, export
  compliance, and approval remain Account Holder responsibilities.
- Developer ID distribution and notarisation remain a separate future path.

This decision prepares the repository for distribution. It does not authorise
an upload, TestFlight invitation, App Review submission, or public release.
