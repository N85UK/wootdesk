---
title: Attachments
description: Sending files with a message, the limits that apply, and how received attachments are handled.
sidebar:
  order: 3
---

## Sending files

Use the attachment control in the composer to pick files. Selected files appear
above the composer and can be removed individually before you send. You can
send a message with attachments and no text.

### Limits

| Limit | Value |
| --- | --- |
| Files per message | 15 |
| Total size per message | 25 MB |

Both are checked as you add files, not when you press send, so you find out
before writing a reply.

### File types that are refused

WootDesk will not upload directly executable or script files. These are
rejected when you pick them, before the file is read:

```text
app  bat  cmd  com  command  cpl  dmg  exe  hta  jar  js  jse
lnk  msi  msc  pkg  ps1  reg  scpt  scr  sh  vb  vbe  vbs  wsf  wsh
```

A helpdesk reply is not a software distribution channel, and this stops the app
being used to hand executable content to a customer. If you genuinely need to
send one, compress it first, or use a channel intended for file delivery.

### Other reasons a file is refused

- The item is not a readable file, for example a folder or a broken alias.
- The file is empty.
- The file is larger than the 25 MB per-message limit on its own.
- Adding it would exceed 15 files or 25 MB in total.
- You cancelled the picker, or the import was abandoned.

Each of these is explained in the composer rather than failing silently, and a
refused file never becomes a partial upload.

## Receiving files

Attachments on incoming messages are shown as metadata: type, name where one is
available, and size. WootDesk does **not** fetch them automatically.

Opening one is an explicit action and asks you to confirm first, because it
sends a request to the address the attachment names. Only `https://` addresses
are accepted; an attachment carrying an `http://` address, a `file://` address
or a URL with credentials in it yields no openable link at all.

This applies to cached content too. If a saved copy of a conversation is edited
on the device to carry an unsafe address, the address is discarded when the
copy is read back.

## Where attachment data lives

Files you have selected but not yet sent are held **in memory only**. They are
discarded when you switch conversation or server profile, and they are never
written to the device, including when
[offline storage](/guides/offline) is enabled. Only draft text is saved, not
attachment bytes.
