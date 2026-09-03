---
title: Security
description: Transport security, credential storage, sandboxing and how to report a vulnerability.
sidebar:
  order: 1
---

## Transport

Release builds require HTTPS with a certificate the operating system already
trusts. There is no setting to accept a self-signed or expired certificate, and
no way to disable transport security.

Plain HTTP is permitted only for `localhost`, `127.0.0.1` and `::1`, and only
in a debug build compiled from source.

## Credentials

Chatwoot access tokens are stored **only** in the Apple Keychain, keyed by the
server profile's internal identifier, with a device-only protection class that
keeps them unavailable until the device has been unlocked once after a restart.

Tokens are never written to the profile file, `UserDefaults`, property lists,
logs, screenshots, or the offline records. A token is transmitted only to the
Chatwoot server its profile names, as an authentication header.

The gateway registration details, if you configure notifications, are held in a
separate Keychain item rather than in the profile JSON.

## Sandboxing

The macOS build runs in the App Sandbox with outbound network access only. It
requests no file-system access beyond the files you explicitly choose in the
attachment picker, and no camera, microphone, location or contacts access on
any platform.

## Content handling

- Message HTML from Chatwoot is converted to safe text for display. Embedded
  links are shown but are not made active.
- Attachment addresses are accepted only over HTTPS, and never with credentials
  embedded in the URL. This check is applied again when a saved copy is read
  back from the device, so an edited cache file cannot widen what the app will
  open.
- A received attachment is fetched only when you explicitly confirm it.
- Executable and script file types are refused before upload.

## Data at rest

If [offline storage](/guides/offline) is enabled, unsent drafts and previously
loaded messages are written to the app's storage directory, protected as
described there and excluded from device backups. It can be switched off, which
also deletes what was stored.

## Reporting a vulnerability

Do **not** open a public issue for a security problem.

Follow the reporting process in
[`SECURITY.md`](https://github.com/N85UK/wootdesk/blob/main/SECURITY.md) in the
repository, which names the current contact route and expected response times.

When reporting, never include a real access token, real customer data or a real
conversation. See [Getting support](/help/support) for what to send instead.
