---
title: Troubleshooting
description: Symptom-based checks for connection, certificate, account, attachment and notification problems.
sidebar:
  order: 1
---

:::danger[Never paste a real token]
Whatever you are diagnosing, do not put a real access token, a real customer
message or a real contact's details into an issue, a screenshot or a chat.
Revoke the token in Chatwoot if you think it has been exposed.
:::

## Validation fails when adding a server

Work through these in order.

**Check the address resolves and serves Chatwoot.** Open the same address in a
browser on the same network. If the browser cannot reach it, WootDesk cannot
either.

**Check the scheme.** Release builds require `https://`. If your server is only
on plain HTTP, WootDesk will not connect to it, and there is no override.

**Check the certificate.** The certificate must be valid for the exact hostname
you typed and must chain to a root your device already trusts. A certificate
issued to `example.com` will not validate for `help.example.com`. A private or
internal certificate authority must be installed and trusted on the device
first.

**Check the token type.** It must be an **Application API personal access
token** from your Chatwoot profile settings, not an agent bot token, a platform
app token or a session cookie.

**Check the token is current.** Tokens can be regenerated in Chatwoot, which
invalidates the previous one. If you regenerated it recently, copy the new one.

**Check for a path prefix.** If Chatwoot is served under a subdirectory, the
address must include it, for example `https://example.com/support`.

## "Unauthorised" after it previously worked

The token has been revoked or regenerated in Chatwoot, or your agent account
has been deactivated. Edit the profile and paste a current token.

## "Forbidden" on an action that used to work

Your Chatwoot permissions changed. WootDesk can only do what your agent account
can do; it does not request elevated access. Ask whoever administers the server.

## No accounts to choose from

The token reaches no Chatwoot account. Confirm in the browser that your user is
a member of at least one account on that server.

## The conversation list is empty

**Check the status filter.** An active filter of Resolved or Snoozed will hide
an otherwise busy queue. Clear it to see every status.

**Check the account.** A profile is bound to one account. If you have several,
confirm the active profile is the one you mean.

**Check search.** The search field filters conversations already loaded on the
device, not the server. Clear it, then page further down the list.

## I cannot find an older conversation

Search filters what is loaded, not the whole server. Load more of the list
first, then search again.

## An attachment will not attach

| Symptom | Cause |
| --- | --- |
| Refused immediately by type | The extension is on the executable deny-list. See [Attachments](/guides/attachments). |
| "Larger than the 25 MB limit" | The single file exceeds the per-message limit |
| "Exceed the 25 MB per-message limit" | The files together exceed it |
| "Up to 15 attachments" | Too many files for one message |
| "Not a readable file" | A folder, a broken alias, or something the picker could not open |
| "The file is empty" | Zero bytes |

## A received attachment will not open

WootDesk opens only `https://` addresses, and never a URL with credentials
embedded. If your Chatwoot serves attachments over plain HTTP, or from a
storage host with an unusual URL shape, the link will not be offered. Open the
conversation in the Chatwoot web interface instead.

## I am not getting notifications

Remote delivery is **not switched on**. Nobody is receiving new-message
notifications from WootDesk today. See [Notifications](/guides/notifications)
for what exists and what remains.

## A reply may or may not have sent

WootDesk told you it could not confirm the result. Refresh the conversation and
look before sending again: the server may already have the message, and there
is no way to ask it. See
[Replies and private notes](/guides/replies-and-notes#when-a-send-fails).

## The timeline says "saved copy"

The refresh failed, so you are looking at messages stored on the device from an
earlier load. The capture time is shown beside it. Newer messages will not
appear until a refresh succeeds. See [Working offline](/guides/offline).

## Something is still wrong

See [Getting support](/help/support) for what to send and where.
