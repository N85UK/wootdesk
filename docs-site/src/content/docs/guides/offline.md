---
title: Working offline
description: What WootDesk keeps on the device so you can carry on through a lost connection, and how to turn it off.
sidebar:
  order: 8
---

WootDesk keeps a small, bounded amount of content on the device so a dropped
connection does not cost you work. It is not an offline mode: you cannot triage,
assign or send while disconnected, and the server remains the source of truth.

## What is kept

When offline storage is on, and only for the server profile it belongs to:

- **Unsent draft text**, including whether it was a reply or a private note.
- **The messages already loaded** for a conversation you have opened.
- **A record of any send whose result could not be confirmed.**

Attachment bytes are never stored. Access tokens are never stored here; they
stay in the Apple Keychain.

## How it behaves

**Your draft comes back.** Close the app mid-sentence and the text is there
when you return to that conversation, in the mode you were writing in. It comes
back only under the profile you wrote it in.

**Old messages stay readable.** If a refresh fails while you are offline, the
timeline keeps the messages it already had rather than emptying. It is labelled
as a saved copy, with the time it was captured, so you are never left thinking
a stale conversation is current.

**An unconfirmed send is flagged.** See
[Replies and private notes](/guides/replies-and-notes#when-a-send-fails).

## How it is protected

Records are filed per server profile in the application's own storage
directory. On iPhone and iPad they are written with a protection class that
keeps them encrypted until the device has been unlocked once after a restart,
matching how the access token is held. On Mac they rely on FileVault, which is
the only per-file protection macOS offers.

The directory is excluded from device backups, so drafts and cached messages do
not travel into an iCloud or computer backup.

## What deletes it

| Event | Effect |
| --- | --- |
| The message sends | That draft is deleted |
| You clear the draft | Its record is deleted rather than storing blank text |
| You remove the server profile | Every record for that profile is deleted |
| You switch offline storage off | Everything already stored is deleted |

## Turning it off

**Settings → Offline Storage → Keep Drafts and Recent Messages.**

Switching it off deletes what has already been saved, and stops anything
further being written. Connecting, browsing conversations, replying, triage and
notifications all continue to work normally while you are online. You simply
lose the draft recovery and the readable-while-offline timeline.

Turn it off if the device is shared, if it is not encrypted, or if your
organisation's policy does not permit customer message content at rest on a
mobile device.
