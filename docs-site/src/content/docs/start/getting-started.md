---
title: Install and connect
description: Add a Chatwoot server profile to WootDesk and understand where your access token is stored.
sidebar:
  order: 2
---

## Before you start

Read [Requirements](/start/requirements) first. You need a reachable Chatwoot
server on HTTPS, and an Application API personal access token from your own
Chatwoot profile.

## Getting the app

There is no public download. The current build reaches a closed internal
TestFlight group on iPhone and iPad. If you have been invited, you will have
received a TestFlight link by email; install TestFlight from the App Store,
open the link, and install WootDesk from there.

If you have not been invited, you can still build from source. See the
repository's `README.md` and `CONTRIBUTING.md` at
[github.com/N85UK/wootdesk](https://github.com/N85UK/wootdesk).

## Creating your access token in Chatwoot

1. Sign in to your Chatwoot server in a browser.
2. Open your **Profile Settings**.
3. Find the **Access Token** section.
4. Copy the token.

The token is shown by Chatwoot, not by WootDesk. Copy it directly into the app
rather than storing it somewhere else on the way.

## Adding a server profile

1. Open WootDesk. On first launch it asks you to add a connection.
2. Enter the **server address**. The hostname is enough; WootDesk normalises
   what you type. All of these reach the same place:

   ```text
   help.example.com
   https://help.example.com
   https://help.example.com/
   ```

   A path prefix is preserved, so a Chatwoot served under a subdirectory works:

   ```text
   https://example.com/support
   ```

3. Paste the **access token**.
4. Give the profile a **display name**. This is only a label for you, so use
   something you will recognise when switching servers.
5. Choose **Validate**.

WootDesk calls Chatwoot's profile endpoint to check the address and token
before saving anything. If validation fails, nothing is written to the device.

## Choosing an account

If the token reaches one account, WootDesk selects it and finishes. If it
reaches several, pick the one this profile should use. To work in more than one
account, save a separate profile for each; they can share the same server
address and token.

## Where your token goes

The token is written to the **Apple Keychain**, keyed by the profile's internal
identifier, with a device-only protection class that keeps it unavailable until
the device has been unlocked once after a restart. It is never written to the
profile file, to `UserDefaults`, to logs, or to the offline records.

The non-secret parts of a profile, the display name, server address, selected
account and timestamps, are stored as JSON in Application Support.

The token is sent only to the Chatwoot server that profile names, and only as
an authentication header on requests to it.

## Checking it worked

After validation you land on the conversation list for the selected account. If
it is empty, that is either a genuinely empty queue or a filter: check the
status filter is set to the one you expect. See
[Conversations](/guides/conversations).

## Adding more servers

Open **Settings** and add another connection. Each profile keeps its own
Keychain credential. Switching profiles clears the conversation and message
views so one server's content is never shown under another's name.

Removing a profile deletes its Keychain credential and any saved drafts or
cached messages for it. See [Server profiles](/guides/server-profiles).
