---
title: Server profiles
description: Managing several Chatwoot connections, switching between them, and removing one completely.
sidebar:
  order: 7
---

A **server profile** is one saved connection: a server address, an access
token, a selected Chatwoot account, and a display name you choose.

## Several servers, or several accounts

Save as many profiles as you need. Two profiles may point at the same server
with different accounts, or at entirely different servers. Each holds its own
credential in the Keychain.

## Switching

Switching the active profile clears the conversation list, the open
conversation and the composer, so one server's content is never displayed under
another's name. Anything saved on the device for the profile you left stays
filed under that profile and is not readable while another is selected.

## Editing

A profile's address, token and account can be changed. WootDesk revalidates
against the server before saving. If validation fails, the previous working
values are kept.

## Removing a profile

Removing a profile is deliberately transactional, and it happens in this order:

1. The gateway registration for the profile is removed, if one exists.
2. The profile metadata is removed and the change is persisted.
3. The Keychain credential is deleted.
4. Every saved draft, cached message page and unconfirmed-send record for that
   profile is deleted.

If step 3 fails, the profile metadata is restored so you are not left with a
credential on the device belonging to a profile you can no longer see. If step
4 fails you are told, because local content would remain until you retry; the
profile itself is still gone and unusable, since its credential is not.

## What is left behind

Nothing that can be used. After removal there is no token, no draft and no
cached message for that profile.

A corrupt profile **metadata** file may be kept as a recovery copy. Recovery
copies never contain an access token. Damaged offline records are deleted
rather than kept, because a cached page can be fetched again and an unreadable
draft cannot be recovered anyway.
