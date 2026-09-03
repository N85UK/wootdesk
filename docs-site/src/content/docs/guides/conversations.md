---
title: Conversations
description: Browsing, filtering, searching and opening conversations in WootDesk.
sidebar:
  order: 1
---

## The list

The conversation list shows the queue for the account your active server
profile is connected to. Each row carries the contact, the most recent
activity, the status and, where set, the priority and assignment.

The list is read from Chatwoot each time you open or refresh it. WootDesk does
not keep a synchronised copy of your whole queue, so what you see is what the
server returned for that request.

## Filtering by status

Chatwoot's four statuses are all available as filters:

| Status | Meaning |
| --- | --- |
| Open | Active and awaiting work |
| Pending | Waiting on someone or something |
| Snoozed | Hidden until a return time you set |
| Resolved | Closed |

Clearing the filter shows every status together.

On a Mac or iPad the filter is a segmented control. At large accessibility text
sizes, and on iPhone, it becomes a menu instead, so the labels stay readable
rather than being clipped.

## Loading more

The list pages as you scroll. Each page is a separate request to Chatwoot, and
a page that fails to load leaves the conversations you already have on screen
rather than emptying the list.

## Searching

The search field filters the conversations **already loaded** on the device. It
is not a server-side search, so it will not find a conversation that has not
been paged in yet. Load more of the list first if what you are looking for is
older than the current page.

## Opening a conversation

Selecting a row opens the message history. On iPhone this pushes a new screen;
on iPad and Mac it fills the detail column beside the list. See
[Replies and private notes](/guides/replies-and-notes) for the composer, and
[Triage](/guides/triage) for the actions.

## Refreshing

- **iPhone and iPad:** pull down on the list or the message timeline.
- **Mac:** use the refresh control in the toolbar. There are two, and they do
  different things: one refreshes the conversation list, the other refreshes
  the open conversation's messages.

There is no automatic live update. WootDesk does not hold a WebSocket to
Chatwoot, so a new message arrives when you refresh, not before. Live updates
are planned but not built.
