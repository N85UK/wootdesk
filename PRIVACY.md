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
app memory unless the user deliberately enrols the active profile with a
WootDesk Push Gateway they or their organisation selected.

N85 Dev now operates one such gateway at `https://push.n85.app`, deployed on
2 September 2026. It is **not a default**: the app ships with no gateway
address, and remote delivery stays off until a user enters an address and a
device API token themselves. A user who self-hosts the gateway, or who never
enables remote delivery, sends nothing to N85 Dev.

For a user who does enrol with the N85 Dev gateway, that gateway receives and
stores the APNs device token encrypted at rest, together with opaque device and
profile UUIDs, the selected Chatwoot account ID, the agent's Chatwoot user ID,
the bundle topic and the APNs environment. The agent user ID is held so that a
conversation assigned to one agent alerts only that agent's devices.

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
- Conversation-list data is held in memory for the active app session.
- Selected attachment bytes are held in memory only. They are discarded when
  their conversation or server context changes and are never written to
  WootDesk application storage.
- When offline storage is enabled, unsent draft text and the messages already
  loaded for a conversation are written to Application Support under
  `WootDesk/Offline/<profile UUID>/`. Records are filed per server profile and
  per conversation, so one profile's drafts and messages are never read while
  another profile is selected. On iOS they are written with the
  "complete until first user authentication" protection class, matching the
  Keychain class used for the access token; on macOS they rely on FileVault.
  The directory is excluded from device backups.
- Offline storage can be switched off in Settings. While it is off, nothing is
  written to the device and anything previously stored is deleted. Connecting,
  browsing conversations and replying continue to work normally.
- A draft is deleted when its message sends. Every draft, cached message and
  unconfirmed-send record for a profile is deleted when that profile is
  removed.
- A record of a send whose result could not be confirmed may be stored
  alongside the draft, so the app can warn before a retry that might post the
  same message twice. It holds the submitted text, whether it was a private
  note, and the attempt time.
- A corrupt profile metadata file may be retained locally as a recovery copy.
  Recovery copies do not contain the access token.
- An APNs device token may be held in process memory after the user enables
  notifications. It is not written to application storage or logs.
- A configured push gateway address, device API token, stable device UUID,
  profile UUID, selected account ID, APNs environment, and update time are
  stored together in a separate Apple Keychain item. They are not written to
  the server-profile JSON.

WootDesk does not place access tokens in `UserDefaults`, property lists, source
code, logs, screenshots, the profile JSON file, or the offline records.
`UserDefaults` holds only the offline-storage on or off preference.

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

If the user configures remote delivery, the app sends the APNs device token,
opaque device and profile UUIDs, selected Chatwoot account ID, the agent's
Chatwoot user ID, bundle topic, and development or production environment to
the selected gateway over HTTPS. It
sends no Chatwoot personal access token, customer name, message body, email
address, phone number, attachment, or custom attribute.

A deployed gateway receives the Chatwoot webhook body at its network boundary
because Chatwoot sends the event. The included implementation processes it in
memory, stores only encrypted device routing and hashed idempotency values, and
sends Apple a generic alert with opaque profile, account, and conversation
identifiers. It does not log or persist the customer message body. The gateway
operator controls its host logs, backups, retention, access, and deletion, so
that operator's privacy information also applies. App Store privacy answers
must describe the actual chosen production deployment before release.

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

Removing a server profile in WootDesk first asks the configured push gateway to
remove its device registration. Only after that succeeds does WootDesk remove
the profile metadata, Chatwoot credential, and gateway Keychain item. A remote
removal failure keeps the local profile so the user can retry. Switching
profiles clears the prior server's conversation state before loading the next
profile.

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
