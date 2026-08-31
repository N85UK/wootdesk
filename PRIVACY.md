# WootDesk Privacy Policy

Last updated: 31 August 2026

WootDesk is an independent native client that connects directly to a Chatwoot
server selected by the user. This policy describes the current foundation
release. It must be reviewed whenever the app adds telemetry, cloud services,
push notifications, or live AI features.

## Summary

WootDesk does not operate an account service, advertising network, analytics
service, or telemetry service. The current app does not send personal data,
customer messages, access tokens, or usage analytics to N85 Dev.

Network requests are sent directly from the device to the Chatwoot server the
user chooses. That server may be self-hosted by the user or provided by another
organisation. The server operator's privacy policy applies to its processing.

If the user enables notifications, the operating system registers WootDesk
with Apple Push Notification service. The resulting device token remains in
app memory and is not currently sent to N85 Dev, Chatwoot, or another push
provider. Remote Chatwoot notification delivery is therefore not active.

## Information processed by the app

WootDesk processes the following information to provide its core features:

- A Chatwoot server address entered by the user.
- A Chatwoot personal access token entered by the user.
- The user's Chatwoot profile and account memberships returned by that server.
- Conversation-list information returned by the selected Chatwoot account,
  including names, message previews, inbox information, status, priority,
  timestamps, and unread counts when available.
- Conversation message content and attachment metadata returned by the selected
  account.
- Reply text, private-note text, and files the user deliberately selects for
  upload to the chosen Chatwoot server.

WootDesk does not ask for an OpenAI API key and does not make a live OpenAI
request in the current release.

## Storage on the device

- Chatwoot access tokens are stored only in Apple Keychain, keyed by the saved
  server profile's UUID.
- Non-secret profile metadata is stored in Application Support as JSON. This
  includes the display name, server address, selected account, and timestamps.
- Conversation-list data is held in memory for the active app session. The
  foundation release does not create an offline conversation database.
- Loaded messages, draft text, and selected attachment bytes are held in memory
  only. They are discarded when their conversation or server context changes
  and are not added to WootDesk application storage.
- A corrupt profile metadata file may be retained locally as a recovery copy.
  Recovery copies do not contain the access token.
- An APNs device token may be held in process memory after the user enables
  notifications. It is not written to application storage or logs.

WootDesk does not place access tokens in `UserDefaults`, property lists, source
code, logs, screenshots, or the profile JSON file.

## Network communication

Release builds require HTTPS and use the operating system's certificate trust
evaluation. WootDesk does not disable certificate validation and does not use a
trust-all network delegate.

The Chatwoot token is sent only to the selected server as an authentication
header for Chatwoot Application API requests. WootDesk does not send the token
to N85 Dev, OpenAI, an analytics provider, or an advertising provider.

When notifications are enabled, Apple processes the platform registration and
notification-permission state under Apple's platform terms. WootDesk can
schedule an invented local test alert that contains no Chatwoot information.
The current app does not transmit its APNs device token to a WootDesk service
and cannot receive remote Chatwoot events while closed. The privacy policy and
App Store answers must be updated before a push provider receives device
registrations or Chatwoot event data.

Received remote attachments are not fetched automatically. WootDesk shows safe
metadata first and asks the user to confirm the destination host before opening
an HTTPS attachment URL in the operating system. The app does not add the
Chatwoot token to that attachment URL request. The destination host can receive
normal network information such as the device's public IP address when the user
chooses to open it.

## Analytics, advertising, and tracking

The current release contains no advertising SDK, analytics SDK, tracking SDK,
or off-device telemetry. WootDesk does not track users across apps or websites.

## Deletion

Removing a server profile in WootDesk removes its saved profile metadata and
deletes the corresponding Keychain token. Switching profiles clears the prior
server's conversation state before loading the next profile.

Uninstalling the app removes its sandboxed application data according to the
operating system's normal behaviour. Apple Keychain retention after uninstall
is controlled by Apple platform behaviour. A user who needs immediate removal
should delete each saved profile in WootDesk before uninstalling the app.

The operator of the selected Chatwoot server controls server-side retention and
deletion. WootDesk cannot delete data held by that server unless a future,
explicit feature is implemented for that purpose.

## Future AI features

No live AI feature is present today. The proposed WootDesk AI Gateway is
documented separately and remains a future milestone. If it is implemented:

- Conversation content will leave the Chatwoot server only after deliberate
  user action and a clear preview.
- Chatwoot access tokens will not be sent to the gateway.
- Internal notes, attachments, email addresses, phone numbers, and custom
  attributes will be excluded by default.
- This policy and the App Store privacy disclosure will be updated before the
  feature is released.

## Children

WootDesk is a business support tool and is not directed at children. The
content displayed by the app comes from the user's selected Chatwoot server and
is controlled by that server's operator.

## Changes to this policy

Material changes will be recorded in this repository and dated at the top of
this file. App Store privacy answers must be reviewed for every release.

## Contact

General product questions can be raised through the
[WootDesk repository](https://github.com/N85UK/wootdesk). Do not include access
tokens, server addresses, customer data, or other personal information in a
public issue.

For a private security or privacy report, use the repository's
[private security advisory form](https://github.com/N85UK/wootdesk/security/advisories/new).
