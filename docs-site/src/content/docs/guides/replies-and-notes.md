---
title: Replies and private notes
description: Sending a public reply or an internal private note, and what happens when a send fails.
sidebar:
  order: 2
---

## Two modes, chosen explicitly

The composer is always in one of two modes, and the mode is shown before you
type rather than being a switch you might miss:

- **Reply** sends a public message. The contact sees it.
- **Private Note** adds an internal note. The contact does not see it.

The send button changes label with the mode, and the composer states who will
see the message. Switching conversations resets the mode to Reply.

## Writing and sending

Type into the composer and choose the send button, or press <kbd>Cmd</kbd> +
<kbd>Return</kbd>. Messages are plain text. WootDesk does not send HTML, and it
does not apply formatting you have not typed.

The draft is cleared only after Chatwoot confirms the message was created. If
you edit the draft while the request is in flight, your newer text is kept
rather than being discarded by the response arriving.

## Reading history

The timeline loads the newest page first and pages backwards on demand through
the **Load older messages** control. Incoming, outgoing, activity and template
messages are distinguished, and private notes are marked as private.

Message bodies that Chatwoot has processed into HTML are converted to safe
text for display. Embedded links are shown but are not made active, so a link
in a customer message cannot be followed by a mis-tap.

## When a send fails

WootDesk distinguishes two different failures, because they need different
responses from you.

### The message definitely was not sent

Your token was rejected, you lack permission, the content was invalid, or the
device had no connection at all so the request never left. The composer reports
the reason and keeps your draft. Retrying is safe.

### The result could not be confirmed

The request reached the network and then the connection dropped, timed out, or
a proxy answered instead of Chatwoot. The server may or may not have created
the message.

WootDesk does **not** report this as sent, and does not report it as simply
failed. It says the outcome could not be confirmed, keeps the draft, and marks
the conversation. If you then send again, it asks you to confirm first.

:::caution[Check before you retry]
Chatwoot's message API has no idempotency key, so WootDesk cannot ask the
server "did you already get this one?". Refresh the conversation and look
before sending again, or you may post the same reply to a customer twice.
:::

This is also why WootDesk has no automatic retry queue. Replaying an
unconfirmed send is exactly how a duplicate reaches a customer. See
[Working offline](/guides/offline).

## Keyboard

| Action | Shortcut |
| --- | --- |
| Send the current draft | <kbd>Cmd</kbd> + <kbd>Return</kbd> |

The composer, mode picker, attachment control and send button are all reachable
by keyboard and are labelled for VoiceOver.
