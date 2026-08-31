# ADR 0004: Native APNs Client and Separate Push Provider

Status: Accepted, client and provider source implemented, deployment pending

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

Remote delivery uses a separate authenticated, self-hostable WootDesk Push
Gateway. Chatwoot sends narrowly filtered webhook events to that gateway, and
the gateway sends minimal APNs payloads. A high-entropy webhook route secret is
mandatory because usable account-webhook signatures vary across Chatwoot
versions. Timestamped HMAC verification is optional when a trustworthy signer
provides the documented contract. The app never sends its Chatwoot token to the
gateway.

The client keeps the APNs token in memory only, stores gateway credentials in a
separate device-only Keychain item, exposes accurate permission and registration
states, and does not claim that remote delivery is configured before gateway
enrolment succeeds. Profile deletion requires remote registration removal
before local profile metadata and credentials are deleted.

The dependency-free provider under `Gateway/` encrypts APNs tokens at rest,
authenticates device mutations, deduplicates device and delivery operations,
accepts public incoming messages only, and sends a generic alert. Its first
recipient policy routes to every enrolled device for an account. Deployment is
blocked where per-agent recipient authorisation is required.

## Consequences

- The app stays native and adds no third-party messaging SDK.
- One WootDesk build can support multiple self-hosted Chatwoot servers.
- Push delivery requires a separately operated provider and Apple capability.
- Gateway deployment, recipient authorisation, registration deletion, and
  profile-safe notification routing acceptance are release requirements.
- Notification privacy and App Store disclosures must be reviewed again when a
  gateway begins receiving device registrations or Chatwoot events.

See [Push Notification Architecture and Activation](../PUSH_NOTIFICATIONS.md)
for the provider contract and acceptance checks.
