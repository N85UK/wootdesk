---
title: Triage
description: Changing status, snoozing, setting priority, assigning and labelling a conversation.
sidebar:
  order: 4
---

Triage actions are in the conversation's actions control, available on iPhone,
iPad and Mac.

## Status

Set a conversation to **Open**, **Pending**, **Resolved** or **Snoozed**.

## Snoozing

Snoozing hides a conversation until a return time. WootDesk offers:

| Option | Returns |
| --- | --- |
| An hour | One hour from now |
| Tomorrow morning | The next morning |
| Next week | The start of next week |

The return time is always in the future. A snooze time in the past is rejected
rather than being sent to the server.

## Priority

Set **Urgent**, **High**, **Medium** or **Low**, or clear the priority
entirely.

## Assignment

Assign the conversation to an agent, or to a team, from the lists your account
provides. You can also unassign it.

## Labels

Add and remove labels from the account's label set.

:::note[Why labels behave slightly differently]
Chatwoot replaces the whole label set on a conversation rather than merging
your change into it. WootDesk therefore reads the conversation's current labels
from the server immediately before writing, so a label added by a colleague
seconds earlier is not silently removed by your change.
:::

## Every change is read back

After any triage action, WootDesk re-reads the conversation from Chatwoot and
displays what the server actually returned. It never shows a value it has only
asked for.

This means a change that the server rejected, or applied differently from what
you asked, shows the real result rather than an optimistic one. It also means
triage needs a working connection: there is no offline triage queue.
