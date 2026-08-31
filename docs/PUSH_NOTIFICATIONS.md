# Push Notification Architecture and Activation

Status: native Apple client foundation implemented, remote Chatwoot delivery not yet active

Last reviewed: 31 August 2026

## Current implementation

WootDesk now has the native Apple-side foundation for notifications on iOS,
iPadOS, and macOS:

- notification permission is requested only after the user chooses **Enable Notifications** in Settings;
- the app registers with Apple Push Notification service (APNs) on each launch
  when permission already allows notifications;
- the device token is kept in process memory only and is never logged or written
  to disk;
- APNs registration errors have a clear user-facing state;
- foreground notifications can use the standard banner, badge, and sound
  presentation;
- a local test notification uses invented copy and contains no Chatwoot data;
- previews and UI tests use an inert notification client and never contact APNs;
- Debug and Release builds select development and production APNs environments
  through generated entitlements.

`script/build_and_run.sh` uses ad-hoc signing for a convenient sandboxed local
launch. Apple does not permit an ad-hoc signature to claim the APNs entitlement,
so that script substitutes `WootDesk-Local.entitlements`, which retains the App
Sandbox but omits push. APNs registration must be tested with a development
certificate and a matching push-capable provisioning profile.

This is not yet end-to-end push delivery. A device token identifies an app and
device to Apple. It does not cause a Chatwoot server to send events. A provider
server must receive authenticated Chatwoot events and send a suitable payload
to APNs.

Apple describes the two separate responsibilities in
[Registering your app with APNs](https://developer.apple.com/documentation/usernotifications/registering-your-app-with-apns)
and
[Setting up a remote notification server](https://developer.apple.com/documentation/usernotifications/setting-up-a-remote-notification-server).

## Why WootDesk does not register its APNs token with Chatwoot

The current Chatwoot source supports `browser_push` and `fcm` notification
subscriptions. Its native push path expects an FCM `push_token`, and the
official Chatwoot mobile app obtains that token from Firebase Messaging before
creating an `fcm` subscription:

- [Chatwoot notification subscription model](https://github.com/chatwoot/chatwoot/blob/develop/app/models/notification_subscription.rb)
- [Chatwoot push notification service](https://github.com/chatwoot/chatwoot/blob/develop/app/services/notification/push_notification_service.rb)
- [Chatwoot mobile notification registration](https://github.com/chatwoot/chatwoot-mobile-app/blob/develop/src/store/settings/settingsActions.ts)

An FCM registration token and an APNs device token are different credentials.
Sending WootDesk's APNs token to Chatwoot's FCM endpoint would create a record
that cannot deliver a notification. WootDesk therefore does not call that
endpoint or report push as active.

Adding Firebase to the app would also require every supported self-hosted
Chatwoot installation to send through the same Firebase project, or require a
separate app build per organisation. That conflicts with WootDesk's goal of one
independent client supporting many user-controlled servers.

## Required provider design

The intended production path is:

```text
Chatwoot account webhook
  -> authenticated HTTPS WootDesk Push Gateway
  -> minimal event and recipient policy checks
  -> Apple Push Notification service
  -> WootDesk on iPhone, iPad, or Mac
```

The gateway may be hosted by an organisation or self-hosted. It must meet these
requirements before WootDesk enables remote delivery:

1. Accept only HTTPS and authenticate both device enrolment and administration.
2. Verify Chatwoot webhook HMAC signatures, enforce a short timestamp window,
   and deduplicate the `X-Chatwoot-Delivery` identifier.
3. Never request or receive a Chatwoot personal access token.
4. Store an APNs token with its APNs environment, bundle topic, opaque device
   identifier, WootDesk profile identifier, and Chatwoot account identifier.
5. Encrypt device registrations at rest and keep Apple signing keys in an
   approved secret store.
6. Send alerts only for an explicitly enabled event policy. The first policy
   should cover new incoming customer messages, not private notes or the user's
   own outgoing replies.
7. Use generic lock-screen text by default. Customer names and message bodies
   must require an explicit privacy choice.
8. Keep only opaque routing identifiers in the APNs custom payload. Fetch the
   conversation from the selected Chatwoot server after the user opens WootDesk.
9. Handle token rotation, profile switching, logout, profile deletion, APNs
   invalid-token responses, rate limits, retries, and registration expiry.
10. Never log device tokens, webhook secrets, Apple keys, message bodies, or
    customer identifiers.
11. Provide retention, deletion, audit, availability, and incident procedures.
12. Rate limit registration and delivery, and reject payloads outside a small
    documented schema.

The Chatwoot webhook secret and any future gateway access token are secrets.
They belong in server secret storage and Apple Keychain respectively, never in
the server-profile JSON file, screenshots, source, or logs.

## App completion work after the gateway exists

The app still needs a small authenticated gateway client that:

1. enrols the current APNs token for an explicit saved profile and account;
2. refreshes enrolment when APNs changes the token;
3. removes the prior enrolment before a profile is deleted;
4. keeps gateway credentials in Keychain under the stable profile UUID;
5. clears old notification routing when the active profile changes;
6. validates an incoming opaque payload and opens the correct saved profile and
   conversation without briefly showing data from another server.

These operations require a defined gateway API and authentication mechanism.
They must not be simulated by a success-only local implementation.

## Apple Developer activation

Before a signed build can register with APNs:

1. enable the Push Notifications capability for the explicit App ID
   `dev.n85.wootdesk` in Certificates, Identifiers and Profiles;
2. regenerate the iOS App Store and Mac App Store provisioning profiles after
   enabling the capability;
3. let Xcode download the refreshed profiles;
4. archive a new build number, never reuse build 3;
5. inspect the signed iOS entitlement `aps-environment` and the signed macOS
   entitlement `com.apple.developer.aps-environment`;
6. verify that Release archives resolve the value to `production`;
7. confirm the App Store privacy answers against the final provider's actual
   collection, retention, and notification-content behaviour.

WootDesk does not enable background fetch or remote-notification background
mode in this foundation. A standard visible APNs alert does not require either.
Add a background mode only if a later, reviewed feature genuinely performs
silent background reconciliation.

## Verification

Local deterministic checks:

```bash
xcodegen generate --spec project.yml
xcodebuild test \
  -project WootDesk.xcodeproj \
  -scheme WootDesk \
  -destination 'platform=macOS,arch=arm64' \
  -only-testing:WootDeskTests \
  CODE_SIGNING_ALLOWED=NO
./script/ci.sh
```

Signed device acceptance must separately prove all of the following:

- permission can be granted, denied, and changed in System Settings;
- the local test notification appears with the app foregrounded and closed;
- APNs registration succeeds on a physical iPhone, iPad, and Mac;
- a real invented-data Chatwoot `message_created` event reaches the gateway;
- the gateway sends one production APNs notification to the intended device;
- tapping the notification selects the right profile before loading data;
- a token refresh preserves delivery;
- deleting a profile unregisters the device;
- a notification never crosses profiles, accounts, users, or environments.

Until the provider, signed capability, and physical-device acceptance all pass,
remote new-message notifications remain a release blocker and must not be
advertised as available.
