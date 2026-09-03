# Push Notification Architecture and Activation

Status: native client and self-hostable gateway implemented, deployment and signed-device acceptance pending

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
- the app can enrol, update, and remove one gateway registration per saved
  profile after APNs has supplied a device token;
- each gateway address, device API token, and stable device identifier is stored
  together in a separate Apple Keychain service under the profile UUID;
- APNs token rotation refreshes every configured saved profile, while switching
  profiles refreshes the active profile's account routing;
- deleting a server profile first removes its gateway registration. A failed
  remote removal keeps the profile and Chatwoot credential so stale routing is
  never silently abandoned;
- notification taps validate the opaque profile, account, and conversation
  identifiers before switching profiles and loading the first conversation page.
- a notification tap received during cold launch is retained until the root app
  state is ready, and returning from System Settings retries Apple registration
  after permission is granted.

`script/build_and_run.sh` uses ad-hoc signing for a convenient sandboxed local
launch. Apple does not permit an ad-hoc signature to claim the APNs entitlement,
so that script substitutes `WootDesk-Local.entitlements`, which retains the App
Sandbox but omits push. APNs registration must be tested with a development
certificate and a matching push-capable provisioning profile.

This repository also contains the WootDesk Push Gateway under `Gateway/`. Its
deterministic tests exercise device authentication, encrypted token storage,
webhook filtering, APNs token signing, idempotency, invalid-token removal, and
generic payload creation. This source is not evidence of a deployed service.
End-to-end delivery still requires Apple credentials, a hardened HTTPS
deployment, Chatwoot webhook configuration, enrolled signed devices, and the
acceptance matrix below.

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

## Implemented gateway design and release boundary

The intended production path is:

```text
Chatwoot account webhook
  -> authenticated HTTPS WootDesk Push Gateway
  -> minimal event and recipient policy checks
  -> Apple Push Notification service
  -> WootDesk on iPhone, iPad, or Mac
```

The gateway may be hosted by an organisation or self-hosted. The implementation
meets the following source-level boundaries:

1. Accept only HTTPS and authenticate both device enrolment and administration.
2. Require a high-entropy secret in the webhook route. Timestamped HMAC
   verification is available only when a trustworthy Chatwoot version or
   ingress adapter supplies the documented headers. Current account-webhook
   signature behaviour varies, so the route secret remains mandatory.
3. Never request or receive a Chatwoot personal access token.
4. Store an APNs token with its APNs environment, bundle topic, opaque device
   identifier, WootDesk profile identifier, and Chatwoot account identifier.
5. Encrypt device registrations at rest and keep Apple signing keys in an
   approved secret store.
6. Send alerts only for new public incoming messages. Private notes, outgoing
   replies, unsupported events, and ambiguous privacy values are ignored.
7. Use generic lock-screen text by default. Customer names and message bodies
   must require an explicit privacy choice.
8. Keep only opaque routing identifiers in the APNs custom payload. Fetch the
   conversation from the selected Chatwoot server after the user opens WootDesk.
9. Handle token rotation, profile switching, logout, profile deletion, APNs
   invalid-token responses, rate limits, retries, and registration expiry.
10. Never log device tokens, webhook secrets, Apple keys, message bodies, or
    customer identifiers.
11. Provide retention, deletion, audit, availability, and incident procedures
    in the operator's deployment runbook.
12. Rate limit registration and delivery, and reject payloads outside a small
    documented schema.

The recipient policy is recorded in `DEC-008`. An assigned conversation
notifies only the assignee's devices. An unassigned one notifies every agent on
the account, matching how Chatwoot itself treats an unassigned conversation,
because assignee-only with no fallback would mean an unassigned message reaches
nobody.

The agent identity comes from `GET /api/v1/profile` and is stored on the server
profile, then sent at enrolment. A registration without one still enrols, but
can never match an assigned conversation, so it is excluded and reported as
`unroutable_registrations` rather than being notified about a colleague's
conversation.

### Acceptance evidence, 3 September 2026

Exercised against the deployed gateway and a real APNs delivery path, not unit
tests. Three registrations were created on an invented account (`424242`) with
invented agent identifiers, so a genuine Chatwoot webhook could never select
them and these events could never select a genuine registration:

| Registration | Agent | APNs token |
| --- | --- | --- |
| A | 9001 | The maintainer's real iPhone token, recovered from the store |
| B | 9002 | Well formed, deliberately unregistered |
| C | none | Well formed, deliberately unregistered |

Signed webhooks were posted to the live endpoint, matching how Chatwoot signs.

| Case | Assignee | Result | Reading |
| --- | --- | --- | --- |
| 1 | agent 9001 | `delivered 1, invalidated 0`, plus a warning `unroutable_registrations count 1` | Only A was selected. The real iPhone was notified. B was excluded as a different agent, C as identity-less |
| 2 | agent 9002 | `delivered 0, invalidated 1` | Only B was selected, and APNs rejected its token. **A was not selected**, so the real device stayed silent for another agent's conversation |
| 3 | unassigned | `delivered 1, invalidated 2` | All three were selected, including the identity-less C, matching the documented fallback |

Case 2 is the isolation proof: had A been selected, `delivered` would have been
at least 1. Every test registration was deleted afterwards and the maintainer's
own registration was left untouched.

The one gap: the negative side used a stand-in token rather than a second
physical device, because enrolling a second device requires notification
permission and profile entry that cannot be automated. What is proven is that
the gateway does not select another agent's device and that the real device
receives nothing. What is not proven is a second handset visibly staying quiet.

Two behaviours were confirmed as a side effect. A registration whose token APNs
rejects is pruned immediately, so B had to be recreated between cases. And the
identity-less exclusion is reported as a `warn`, not an error, which is why it
went unnoticed when it was excluding the only enrolled device.

### Recipient scoping is single-tenant

Recipients are selected by Chatwoot account id and agent id alone. Nothing
identifies which Chatwoot server the event came from, and the gateway holds one
webhook signing secret. Two Chatwoot deployments that both have an account `1`,
pointed at the same gateway, therefore share a routing namespace: an event from
one can notify devices enrolled against the other. This is acceptable for a
single-deployment gateway, which is what is deployed, but it is a real
constraint on the multi-profile feature the app otherwise supports, and it
should be closed before the gateway serves more than one Chatwoot.

Tracked as N85-64 under the post-1.0 epic N85-37.

The Chatwoot webhook route secret and gateway device API token are secrets.
They belong in server secret storage and Apple Keychain respectively, never in
the server-profile JSON file, screenshots, source, or logs.

## Current app-side gateway integration

The app now has an authenticated gateway client that:

1. enrols the current APNs token for an explicit saved profile and account;
2. refreshes enrolment when APNs changes the token;
3. removes the prior enrolment before a profile is deleted;
4. keeps gateway credentials in Keychain under the stable profile UUID;
5. clears old notification routing when the active profile changes;
6. validates an incoming opaque payload and opens the correct saved profile and
   conversation without briefly showing data from another server.

The API contract, deployment configuration, secret handling, and operational
gates are documented in [`Gateway/README.md`](../Gateway/README.md). Previews and
UI tests use an inert manager that never simulates successful enrolment.

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
cd Gateway
npm test
npm run check
cd ..
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
