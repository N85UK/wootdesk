# ADR 0004: Native APNs Client and Separate Push Provider

Status: Accepted for client foundation, provider implementation pending

Date: 31 August 2026

## Context

WootDesk needs new-message notifications while the app is not active. Apple
requires a provider server to send remote notifications through APNs. Current
Chatwoot native notification subscriptions accept FCM registration tokens, not
raw APNs device tokens. The app must support multiple unrelated self-hosted
Chatwoot installations without bundling their server credentials or assuming
they share one Firebase project.

## Decision

WootDesk uses native UserNotifications APIs and direct APNs registration on
iOS, iPadOS, and macOS. It does not add Firebase or submit an APNs token to
Chatwoot's FCM subscription endpoint.

Remote delivery will use a separate authenticated, self-hostable WootDesk Push
Gateway. Chatwoot sends signed webhook events to that gateway, and the gateway
sends minimal APNs payloads. The app never sends its Chatwoot token to the
gateway.

The current client keeps the APNs token in memory only, exposes accurate
permission and registration states, and does not claim that remote delivery is
configured before a gateway enrolment succeeds.

## Consequences

- The app stays native and adds no third-party messaging SDK.
- One WootDesk build can support multiple self-hosted Chatwoot servers.
- Push delivery requires a separately operated provider and Apple capability.
- Gateway authentication, webhook verification, registration deletion, and
  profile-safe notification routing are release requirements.
- Notification privacy and App Store disclosures must be reviewed again when a
  gateway begins receiving device registrations or Chatwoot events.

See [Push Notification Architecture and Activation](../PUSH_NOTIFICATIONS.md)
for the provider contract and acceptance checks.
