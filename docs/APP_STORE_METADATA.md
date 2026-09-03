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

## Live App Store Connect state, read 3 September 2026

Read from the API rather than assumed, so this can be checked rather than
believed.

| Item | State |
|---|---|
| App record | `PREPARE_FOR_SUBMISSION`, iOS and macOS versions both present |
| Age rating | `FOUR_PLUS`, Brazil `L` |
| Description | Set, 2075 characters |
| Keywords | Set, 98 characters |
| Promotional text | Set, 97 characters |
| Support and marketing URLs | Both set |
| Screenshots | Two sets: `APP_IPHONE_65` and `APP_IPAD_PRO_3GEN_129` |
| What's New | **Empty** |
| App Review contact name and email | **Empty** |
| Demo account | **Empty**, and `demoAccountRequired` is unset |
| Review notes | **Empty** |

The review details are the gap that matters. WootDesk cannot be assessed
without a Chatwoot server, so a reviewer given no demo environment and no notes
will reject it as non-functional. `AC5` of N85-18 and `GO-008` both depend on
this, and the compatibility stack in `compat/` is the obvious candidate for a
review environment, though it is currently torn down after each run and would
need to stay up for the review window.

macOS has no screenshot set of its own recorded here.

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

**This answer needs deciding, not copying. The premise it was written on has
changed.**

The draft previously read: "The current code sends no data to N85 Dev and
contains no analytics or tracking SDK, so a candidate response is No, we do not
collect data from this app."

That was true when written. On 2 September 2026 N85 Dev deployed a WootDesk
Push Gateway at `https://push.n85.app`. A user who enrols with it transmits the
following to a server N85 Dev operates:

| Data | Notes |
|---|---|
| APNs device token | Stored encrypted at rest, removed when Apple reports it invalid |
| Device UUID and profile UUID | Opaque, generated by the app |
| Chatwoot account ID | Integer |
| Chatwoot agent user ID | Added for per-agent routing, so an assigned conversation alerts only the assignee |
| APNs environment and bundle topic | |

No Chatwoot access token, customer name, message body, email address, phone
number or attachment is ever sent.

### Why this is genuinely arguable rather than obviously "yes"

The gateway is **not a default**. The app ships with no gateway address and
remote delivery stays off until the user enters an address and a device API
token. A user who self-hosts, or who never enables remote delivery, sends N85
Dev nothing. The gateway is also self-hostable by design, and the shipped
source is the same one N85 Dev runs.

So the honest question for the Account Holder is: does the app "collect" data
when it can transmit device identifiers to a first-party server, at the user's
explicit configuration, with no default pointing there? Apple's definition
turns on whether the developer or its partners receive the data, and for the
subset of users who choose the N85 Dev gateway, N85 Dev does.

**A plausible answer is Identifiers, Device ID, used for App Functionality,
linked to the user**, given the agent user ID ties a device to a person. It is
not a tracking use, so `NSPrivacyTracking` stays false.

**Do not publish "we do not collect data" without deciding this deliberately.**
An inaccurate privacy answer is both a review-rejection risk and a compliance
problem, and it is harder to correct after publication than before.

### The privacy manifest also needs review

`PrivacyInfo.xcprivacy` currently declares empty `NSPrivacyCollectedDataTypes`
and no accessed API types. If the answer above changes, the manifest should
change with it, and the two must agree.

The Account Holder must confirm the final answer against the exact release
build, the selected demo environment, linked services, and Apple's current
definition of collection before publishing.

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
