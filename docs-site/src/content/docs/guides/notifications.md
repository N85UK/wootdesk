---
title: Notifications
description: How WootDesk handles push notifications, what is built, and what is not yet switched on.
sidebar:
  order: 6
---

:::caution[Not yet active]
Remote delivery of new-message notifications is **not switched on**. The
application side is complete and the push gateway source is in the repository,
but the gateway has not been deployed, its recipient policy has not been
approved, and delivery has not completed acceptance on real hardware. Do not
rely on WootDesk to alert you to a new message today.
:::

## The design

Chatwoot's own mobile push path is built for Firebase Cloud Messaging.
WootDesk does not use it, and does not send an Apple push token to a Firebase
endpoint.

Instead there are three parties:

1. **WootDesk** on your device registers with Apple Push Notification service
   and receives an APNs token.
2. **The WootDesk Push Gateway**, a small self-hostable service in the same
   repository, holds that token encrypted, receives events from Chatwoot, and
   asks Apple to deliver a notification.
3. **Apple Push Notification service** performs the delivery.

You run the gateway, or you nominate someone who does. There is no N85-operated
gateway, and if you never configure one, no push registration happens at all.

## What the gateway is told

When you enable notifications for a profile, the device sends the gateway its
APNs token, an opaque device identifier, an opaque profile identifier, the
Chatwoot account ID, your agent identifier, and the APNs environment.

It is not told your access token, your server address, or any message content.

## What a notification contains

Notification payloads are deliberately thin. They carry the identifiers needed
to find the conversation, not the message text. When you open a notification,
WootDesk fetches the conversation from your Chatwoot server using your own
credential.

## Routing

A notification for a conversation assigned to one agent reaches only that
agent's devices. An unassigned conversation falls back to every agent enrolled
on that account.

:::note[Check this suits your organisation]
The account-wide fallback means an unassigned conversation can alert every
enrolled agent. If your organisation requires strict per-agent routing with no
fallback, review the gateway's recipient policy before deploying it.
:::

## Opening the right conversation

Choosing a notification opens the conversation it names, even when that
conversation is not on the loaded page, is hidden by the current status filter,
or is excluded by an active search. WootDesk clears what is in the way and
opens it.

If the conversation cannot be reached, for example it was deleted or your
access changed, WootDesk says so. It never opens a different conversation in
its place.

## Removing a device

Deleting a server profile removes its gateway registration before removing the
local credential. If the gateway cannot be reached, the profile and its
credential are kept rather than leaving a registration behind that would keep
sending notifications to a device that can no longer open them.
