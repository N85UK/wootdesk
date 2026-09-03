---
title: Privacy
description: What WootDesk sends, what it stores, and what it deliberately does not collect.
sidebar:
  order: 2
---

The authoritative text is
[`PRIVACY.md`](https://github.com/N85UK/wootdesk/blob/main/PRIVACY.md) in the
repository. This page summarises it.

## What N85 receives

Nothing.

WootDesk sends no analytics, no crash telemetry, no usage statistics and no
identifiers to N85 or to any third party. There is no advertising SDK and no
cross-app or cross-site tracking. The app has no account with us, because there
is nothing to have an account for.

## Where your data goes

Your device talks to the Chatwoot server you nominated, directly, over HTTPS.
Conversations, messages, attachments and triage actions travel between those
two parties only.

That server sees the normal information any web request carries, including your
device's public IP address.

## What is stored on the device

| Item | Where | Notes |
| --- | --- | --- |
| Access token | Apple Keychain | Device-only protection class |
| Profile metadata | Application Support, JSON | Name, address, account, timestamps |
| Gateway registration | Apple Keychain, separate item | Only if you enable notifications |
| Unsent drafts | App storage, per profile | Only if offline storage is on |
| Previously loaded messages | App storage, per profile | Only if offline storage is on |
| Unconfirmed-send records | App storage, per profile | Only if offline storage is on |
| Selected attachment bytes | Memory only | Never written to storage |
| Offline storage on or off | `UserDefaults` | The preference only |

Offline records are filed per server profile, protected at rest, and excluded
from device backups. See [Working offline](/guides/offline).

## Deletion

Removing a server profile deletes its token, its drafts, its cached messages
and its unconfirmed-send records. Switching offline storage off deletes every
stored draft and cached message.

Deleting the app removes its container, including all of the above.

WootDesk cannot delete anything from your Chatwoot server. To remove
conversation data, use Chatwoot's own tools and your provider's retention
policy.

## What is sent if you enable notifications

Only if you configure a push gateway: the APNs device token, opaque device and
profile identifiers, the Chatwoot account ID, your agent identifier, and the
APNs environment. Not your access token, not your server address, and not any
message content.

Notification payloads carry identifiers rather than message text, so the
message body is fetched from your own server with your own credential when you
open it.
