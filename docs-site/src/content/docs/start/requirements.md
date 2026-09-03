---
title: Requirements
description: The devices, Chatwoot server, network and account access WootDesk needs before it will work.
sidebar:
  order: 1
---

## Apple devices

| Platform | Minimum version |
| --- | --- |
| iPhone | iOS 18.0 |
| iPad | iPadOS 18.0 |
| Mac | macOS 15.0 |

The Mac build is a native universal application for Apple silicon and Intel.
It is not a Catalyst port of the iPad app.

:::caution[Availability]
Meeting these versions does not mean you can install WootDesk. There is no
public release. See [Releases](/releases) for what has actually been
distributed.
:::

## A Chatwoot server

WootDesk is a client. You need a Chatwoot installation already running, either
self-hosted or hosted for you, and an account on it.

Compatibility is verified against Chatwoot **v4.x**, most recently v4.9.0.
Older major versions are not tested and are not supported. Chatwoot's
Application API is stable across patch releases but has changed between major
versions, so a server on a much older or much newer major version may behave
differently.

## HTTPS

Release builds require `https://` and a certificate your device already
trusts, through the operating system's normal certificate validation. There is
no setting to accept a self-signed or expired certificate, and no way to turn
transport security off.

If your Chatwoot server sits behind a reverse proxy, the certificate must be
valid for the hostname you type into WootDesk.

Plain `http://` is permitted only for `localhost`, `127.0.0.1` and `::1`, and
only in a debug build compiled from source. It is unavailable in any build you
would be given.

## A personal access token

WootDesk authenticates with a Chatwoot **Application API personal access
token**, not a username and password. You obtain one from your own Chatwoot
profile settings.

The token carries your own permissions. WootDesk cannot do anything in Chatwoot
that your agent account cannot already do, and it does not request elevated
scopes.

:::danger[Treat the token as a password]
Anyone holding it can act as you in Chatwoot. Do not paste it into a support
ticket, an issue, a screenshot or a chat message. If you think it has been
exposed, revoke it in Chatwoot immediately. See
[Getting support](/help/support) for what to send instead.
:::

## An account on the server

Chatwoot organises work into accounts. If your token has access to exactly one
account, WootDesk selects it for you. If it has access to several, WootDesk
asks which one this server profile should use, and you can save a separate
profile per account.

## Network access

The device needs to reach your Chatwoot server on port 443. WootDesk makes no
other outbound connection: no analytics endpoint, no N85 service, and no
third-party API.

The single exception is push notifications, which are not switched on. If they
are enabled in future, the device would additionally talk to Apple Push
Notification service and to a push gateway that you choose to run. See
[Notifications](/guides/notifications).
