---
title: Getting support
description: Where to report a defect, how to report a security issue, and what to include safely.
sidebar:
  order: 3
---

## Before you report

Check [Troubleshooting](/help/troubleshooting) and
[Known issues](/help/known-issues). Many reports are an already-known
limitation, particularly around notifications and macOS distribution.

## Contacting support

Email <help@n85.app>. This reaches the maintainers directly and is the
right route if you would rather not post in public, or if your report would
otherwise contain details of your Chatwoot server.

## Reporting a defect

For anything that can be discussed openly, open an issue at
[github.com/N85UK/wootdesk/issues](https://github.com/N85UK/wootdesk/issues).
An issue is usually faster, because other people can see it and answer.

Useful reports include:

- What you did, what you expected, and what happened instead.
- The platform and OS version, for example "iPad, iPadOS 18.4".
- The WootDesk version and build, from Settings.
- Your Chatwoot **major and minor version**, for example "v4.9".
- Whether it happens every time or intermittently.

## Reporting a security issue

Do **not** open a public issue. Follow
[`SECURITY.md`](https://github.com/N85UK/wootdesk/blob/main/SECURITY.md) in the
repository.

## What never to include

:::danger[Redact before you send]
Never put any of these in an issue, a screenshot, a log excerpt or a chat
message:

- A Chatwoot access token, or any part of one.
- Real customer names, email addresses, phone numbers or message content.
- Your production server hostname, if it is not already public.
- Internal infrastructure detail: private hostnames, internal IP ranges,
  proxy configuration.
:::

## How to describe your setup safely

Substitute reserved names. These are reserved by standards bodies for exactly
this purpose and will never belong to anyone:

```text
https://help.example.com
https://support.example.org
agent@example.com
```

For a token, say "a valid Application API personal access token" rather than
showing one. For a conversation, describe its shape, "an open conversation with
two incoming messages and one private note", rather than pasting it.

For a screenshot, redact the contact column, the message bodies and the server
address before attaching it.

## If you have already exposed a token

Revoke it in Chatwoot immediately, from your profile settings, then generate a
new one and update the profile in WootDesk. A revoked token cannot be used even
if someone has already copied it.

## What to expect

WootDesk is not a commercial product with a support contract. It is an open
project. Response times are best-effort and are set out in the repository's
`SECURITY.md` for security reports and `CONTRIBUTING.md` for everything else.
