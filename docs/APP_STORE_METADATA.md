# Draft App Store Metadata

Status: Draft listing metadata, build 3 local candidate, not submitted for review

Last reviewed: 31 August 2026

This file provides non-secret draft copy for App Store Connect. The release
owner must verify every field against the exact uploaded build. Uploaded build
2 remains the foundation build and does not contain the Milestone 2 source
changes. Build 3 is a local candidate only. Do not add demo credentials,
customer data, or a real server address to this repository.

## Shared product information

| Field | Draft value |
|---|---|
| App name | WootDesk |
| Subtitle | Native support desk client |
| Primary category | Business |
| Secondary category | Productivity |
| Bundle ID | `dev.n85.wootdesk` |
| Copyright | 2026 N85 Dev |
| Price | Free, proposed |
| Support URL | `https://github.com/N85UK/wootdesk` |
| Marketing URL | `https://github.com/N85UK/wootdesk` |
| Privacy policy URL | `https://github.com/N85UK/wootdesk/blob/main/PRIVACY.md` |

The privacy-policy URL becomes a valid release URL only after `PRIVACY.md` is
confirmed accessible from the public default branch without authentication.

## Current submission snapshot

| Item | Verified state |
|---|---|
| App Store Connect record | Present for iOS, iPadOS, and macOS |
| iOS build 1 | Superseded, Missing Compliance |
| iOS build 2 | Uploaded, Ready to Submit |
| Export compliance | `ITSAppUsesNonExemptEncryption = false` in build 2 |
| iOS build 3 | Local archive and App Store export package, not uploaded |
| macOS build 3 | Local universal archive and signed App Store installer package, not uploaded |
| TestFlight testers | None added |
| App Review | Not submitted |
| macOS distribution | Archive and installer package validated locally, not uploaded |

This is a process snapshot, not a public-release approval. The release remains
blocked by the criteria in `docs/RELEASE_READINESS.md`.

## Promotional text

Connect directly to the Chatwoot servers you control with a native app for
iPhone, iPad, and Mac.

## Description draft for the build 3 candidate

WootDesk is an independent native client for Chatwoot installations.

Add one or more Chatwoot servers, validate a personal access token, select an
account, and review a live conversation list from iPhone, iPad, or Mac. Saved
tokens stay in Apple Keychain, while non-secret server profile information stays
in local application storage.

Current features include:

- Multiple saved Chatwoot server profiles.
- Direct validation through the Chatwoot Application API.
- Account selection for users who belong to several accounts.
- Conversation lists with status, priority, inbox, activity, message preview,
  and unread information when the server provides it.
- Paginated conversation message history.
- Plain-text public replies and private internal notes with recoverable in-memory drafts.
- File uploads and safe received-attachment metadata without automatic remote downloads.
- Processed HTML converted to readable text and inline Markdown shown without active embedded links.
- Native navigation, keyboard support, Dynamic Type, VoiceOver-friendly labels,
  pull to refresh, and light and dark appearance support.
- No analytics, advertising, or off-device telemetry.

The uploaded foundation build 2 does not show full message history and cannot
send replies or private notes. Local build 3 adds those flows and attachment
handling, but this copy must not describe them as shipped until a processed
build containing the reviewed source is selected for the platform version.

WootDesk is an independent project. It is not affiliated with, maintained by,
or endorsed by Chatwoot. The Chatwoot name and marks belong to their respective
owners.

## Keywords

`helpdesk,support,inbox,self-hosted,conversation,agent,customer service`

Verify the final comma-separated value against App Store Connect's current
character limit before submission.

## What's New

Proposed build 3 TestFlight candidate:

- Add and validate a Chatwoot server securely.
- Select an account and restore the saved connection.
- Switch between saved servers and remove them safely.
- Load a live conversation list from the selected account.
- Read paginated message history.
- Send public replies and private notes with recoverable drafts.
- Upload attachments and review safe received-attachment metadata.

Do not use this text for a public release until the release-readiness gate is
approved.

## App Review information

Create a dedicated review-only Chatwoot environment containing invented data.
Enter its address, review account details, and token only in App Store Connect's
private App Review fields. Credentials must remain valid for the review period
and must not belong to a customer or production environment.

Suggested review notes:

> WootDesk is an independent native client for an existing Chatwoot server. It
> does not create a Chatwoot account. Use the dedicated review server and token
> supplied in the private sign-in fields. Launch WootDesk, choose Add Chatwoot
> Server, enter the supplied HTTPS address and token, select the supplied account
> if prompted, and choose Connect. The app validates `/api/v1/profile`, saves the
> token in Apple Keychain, and loads the account's conversation list. The demo
> contains invented messages only. No customer data is present.

Add any server-specific test setting to the private Notes field. Never include
a token in the public description, screenshots, attachments, or support URL.

## Screenshot plan

Use a dedicated demo profile with invented names and messages. Capture each
platform at its required App Store size, without showing a real server address,
access token, customer name, email address, phone number, or attachment.

| Order | Screen | Suggested caption |
|---:|---|---|
| 1 | Native conversation list | Your support conversations, natively organised |
| 2 | Invented conversation timeline | Read the full context and older history |
| 3 | Reply and private-note composer | Reply publicly or keep a note within your support team |
| 4 | Invented attachment metadata | Review files without automatic remote downloads |
| 5 | Server profile sidebar | Switch safely between the servers you control |
| 6 | Secure connection setup | Validate your Chatwoot connection before saving |
| 7 | Multiple-account picker | Choose the right account for each server |
| 8 | Empty and retry state | Clear states when a server needs attention |

Do not use build 2 to create screenshots that imply message history or replies.
After build 3 is processed and passes acceptance, screenshots may show message
history, public replies, private notes, and invented attachment metadata from
the dedicated review server. AI results, push notifications, automatic previews,
and other unfinished features must never be implied.

Local screenshot candidates were captured on 31 August 2026 through the
in-memory `StubChatwootAPI`. The iPhone set uses the accepted 1284 by 2778 size,
and the iPad set uses 2064 by 2752. They contain invented names, messages, and
attachment metadata only. They remain outside the repository and have not been
uploaded or approved for publication.

## App privacy draft

The current code sends no data to N85 Dev and contains no analytics or tracking
SDK. A candidate App Store Connect response is therefore "No, we do not collect
data from this app". The Account Holder must confirm this against the exact
release build, the selected demo environment, linked services, and Apple's
current definition of collection before publishing the answer.

The app still processes server addresses, tokens, account information, and
conversation previews on the user's device and selected Chatwoot server. Those
flows are explained in `PRIVACY.md` even though N85 Dev does not receive them.

## Export compliance draft

WootDesk uses operating-system HTTPS and Keychain services and does not
implement its own encryption algorithm. Builds 2 and 3 therefore declare
`ITSAppUsesNonExemptEncryption = false`. App Store Connect processed build 2
without the Missing Compliance state shown for build 1. Build 3 has not been
uploaded, so its server-side compliance state is not yet known. Retain this
declaration only while the app continues to use exempt Apple operating-system
cryptography, and reassess it if the implementation or linked services change.

## Age rating

Complete the current App Store Connect questionnaire from the release build.
WootDesk displays conversation content supplied by an external support server,
so the reviewer must consider user-generated or externally supplied content
accurately. Do not assume a rating in this repository.
