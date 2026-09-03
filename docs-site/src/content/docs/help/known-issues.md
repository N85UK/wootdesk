---
title: Known issues
description: Current limitations and open items in WootDesk, and where each is tracked.
sidebar:
  order: 2
---

Last reviewed: 3 September 2026.

## Not available

| Item | State |
| --- | --- |
| Public App Store release | Not released. Internal TestFlight only, iPhone and iPad. |
| macOS distribution | No build published. Installer signing is incomplete. |
| Push notification delivery | App side complete; gateway not deployed, delivery unverified on hardware. |
| Live updates without refreshing | Not built. Refresh manually. |
| AI summaries, drafting and research | Not built. |
| Server-side conversation search | Not built. Search filters loaded conversations only. |
| Offline triage, assignment or sending | Not built, and not planned as a queue. See below. |
| Languages other than British English | Only British English ships. |

## Deliberate limitations

**No automatic retry of a failed send.** Chatwoot's message API has no
idempotency key, so replaying a request that may already have been applied is
how the same reply reaches a customer twice. WootDesk records the uncertainty
and asks you instead. See
[Replies and private notes](/guides/replies-and-notes#when-a-send-fails).

**Search is local.** The search field filters conversations already paged onto
the device. Adding server-side search means adopting Chatwoot's search
endpoint and its behaviour across versions; it is not done.

**Links in messages are not clickable.** Message HTML is converted to safe
text and embedded links are shown but not activated, so a link in a customer
message cannot be followed by a mis-tap.

**Triage requires a connection.** Every triage change is read back from the
server before it is displayed, so WootDesk never shows a value it has only
requested. There is no offline triage queue.

## Verified compatibility

Chatwoot v4.9.0 has been verified against a dedicated test server carrying
invented records. Other v4.x releases are expected to work but are not
individually verified. Major versions before v4 are not supported.

## Reporting something not listed here

See [Getting support](/help/support).
