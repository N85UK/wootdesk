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

## Support and marketing addresses, set 3 September 2026

| Field | Value |
| --- | --- |
| Support URL, both platforms | `https://docs.n85.app/help/support/` |
| Marketing URL, both platforms | `https://n85.app` |
| App Review contact email | `app.support@n85.dev` |

The support URL was previously the GitHub repository on iOS and empty on macOS.
Empty would have failed submission, because a support URL is required.

**`https://n85.app` does not serve yet.** It returns HTTP 525: the apex is
proxied to the deployment host, which has no TLS certificate for that hostname,
so Cloudflare cannot complete the origin handshake. The marketing URL is
recorded because that is the intended home, but **the site has to be serving
before submission**, or App Review will follow the link and find an error page.
Building it is N85-63.


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
| What's New | Empty, which is correct for a first release |
| App Review contact | **Set** for both platforms: name, email and phone |
| `demoAccountRequired` | **Set to true** on both platforms |
| Review notes | **Set**, 2044 characters, on both platforms |
| Demo account name and password | **Still empty. These are the remaining fields.** |

The review environment exists at `https://review.n85.app`, described in
`review/README.md`, so `GO-008` is satisfied.

**Its containers are currently stopped and the address returns 502.** DNS, the
certificate and the data volumes are kept, so one command restores it with the
same access token and no App Store Connect changes:

```bash
ssh <vps> 'cd <deploy-root>/wootdesk-review && docker compose start'
```

**Start it before submitting.** The review notes name this address, and a
reviewer who cannot reach it will reject the app as non-functional.

Two fields remain, and both hold credentials, so they are entered by hand
rather than through tooling:

| Field | Value |
|---|---|
| Demo account name | `REVIEW_AGENT_EMAIL` from Infisical `prod:/review` |
| Demo account password | `REVIEW_ACCESS_TOKEN` from Infisical `prod:/review` |

The password field holds the **access token**, not the Chatwoot password. That
is deliberate: WootDesk asks for a token rather than a login, so the token is
what makes the reviewer's flow work. The Chatwoot password in
`REVIEW_AGENT_PASSWORD` is only needed if a reviewer wants to sign in to
Chatwoot's own web interface, which the notes do not ask them to do.

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

WootDesk cannot be assessed without a Chatwoot server. A reviewer given no
environment sees a setup screen and nothing else, and the likely outcome is
rejection under Guideline 2.1 as incomplete. The demo environment and these
notes are therefore not optional polish; they are the difference between a
review that can proceed and one that cannot.

Create a dedicated review-only Chatwoot environment containing invented data.
Enter its address, account details and token only in App Store Connect's
private App Review fields. Credentials must stay valid for the whole review
period, including any re-review after a rejection, and must never belong to a
customer or production environment.

### Sign-in required

Set **Sign-in required** to yes and supply the demo agent's email and password
for the Chatwoot server. WootDesk itself does not have accounts, but the
reviewer needs working Chatwoot credentials to obtain the access token, so
answering no here invites a "cannot sign in" rejection.

### Review notes draft

Paste into the private Notes field. Replace the bracketed values.

> WootDesk is an independent, native client for Chatwoot, an open-source
> customer support platform. It is not affiliated with, maintained by, or
> endorsed by Chatwoot, and it does not create Chatwoot accounts. It connects
> to a Chatwoot server that the user already has.
>
> A server is required to use the app at all, so a demo environment is provided.
>
> To review:
>
> 1. Launch WootDesk. The first screen offers Add Chatwoot Server.
> 2. Enter the server address `[REVIEW_SERVER_HTTPS_URL]` and the access token
>    `[REVIEW_ACCESS_TOKEN]`, both supplied in the private fields above.
> 3. Choose Connect. The app validates the token against `GET /api/v1/profile`,
>    stores it in the Apple Keychain, and loads the account's conversations.
>    If prompted to choose an account, select `[REVIEW_ACCOUNT_NAME]`.
> 4. Select a conversation to read its message history, then send a reply or a
>    private note. Both appear only after the server confirms them.
> 5. Conversation actions above the timeline set status, priority, assignee and
>    labels. Every change is read back from the server before it is displayed.
>
> The demo environment contains invented records only. There is no customer
> data, and the conversations and contacts are fictional.
>
> Notifications are optional and off by default. The app requests notification
> permission only when the user enables alerts, and remote alerts additionally
> require the user to enter a separate push gateway address and token. No
> gateway address ships with the app. Reviewing notifications is not necessary
> to assess the app, and remote alerts carry no message content: they read
> "A new message was received."
>
> The app contains no advertising, no analytics, no tracking, and no in-app
> purchases. All network traffic uses HTTPS to the server the user chooses.
>
> The macOS and iOS versions share one codebase and behave the same way. On Mac
> the layout is a three-column split view; on iPhone it is a tab layout.

### Points a reviewer is likely to raise

| Likely question | Answer to have ready |
|---|---|
| "The app requires an account you did not provide" | Sign-in required is set to yes with working demo credentials, and the token is in the notes |
| "The app appears non-functional" | Without a server it shows only the setup screen. The demo server must be reachable for the whole review window |
| "Is this affiliated with Chatwoot?" | No. The listing and notes both say so, and no Chatwoot branding is used |
| "Why does it need notifications?" | Optional, off by default, and never carries message content |

Never include a token in the public description, screenshots, attachments, or
support URL. The private App Review fields are the only place for them.

## What's New

**Not required for the initial 1.0 release.** App Store Connect only requires
this field for subsequent versions, and the API confirms it is currently empty
on the 1.0 record for both platforms. Leaving it empty is correct now.

Draft to adapt for the first update after 1.0:

> This release adds conversation triage, so you can set status, priority,
> assignee and labels without leaving the app. Every change is confirmed by the
> server before it appears.
>
> iPad now uses the same three-column layout as the Mac, and the conversation
> list adapts when the window is narrow.
>
> Notifications open the conversation they belong to, even when it is outside
> the loaded page or hidden by a filter.
>
> Text now stays readable at accessibility sizes throughout the conversation
> list.

Keep it factual and specific. Avoid unverifiable performance claims, and do not
describe a feature before the build carrying it has been uploaded.

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

## App privacy answer

**Decided: yes, the app collects data.** Enter the following in App Store
Connect, App Privacy. The API does not expose these fields, so they are set in
the web interface.

| Question | Answer |
|---|---|
| Do you or your third-party partners collect data from this app? | **Yes** |
| Data type | **Identifiers, Device ID** |
| Purpose | App Functionality |
| Linked to the user's identity | Yes |
| Used for tracking | No |
| Data type | **Identifiers, User ID** |
| Purpose | App Functionality |
| Linked to the user's identity | Yes |
| Used for tracking | No |

Nothing else is collected. There is no advertising, no analytics SDK, no
crash-reporting SDK, no third-party package of any kind, and the app contacts
no host the user has not configured.

### Why "yes", when the app collects nothing by default

This is the judgement in the answer, so the reasoning is recorded rather than
assumed.

Apple defines collecting as transmitting data off the device in a way that lets
the developer or its partners access it for longer than is needed to service
the request in real time.

A user who enables remote notifications enrols with a WootDesk Push Gateway.
That gateway stores an APNs device token, a device UUID, a profile UUID, a
Chatwoot account ID and the agent's Chatwoot user ID for up to 90 days by
default. N85 Dev operates a gateway at `push.n85.app`, so for any user who
chooses it, N85 Dev holds that data well beyond real-time servicing. That is
collection.

The counter-argument is real but does not carry: the app ships with **no**
gateway address, remote delivery stays off until the user enters an address and
a token, and the gateway is self-hostable, so many users will send N85 Dev
nothing at all. Apple's exception for optional data, however, covers
information a user actively provides through the app's interface, not
identifiers gathered automatically. An APNs device token is not user-provided.

Under-declaring is a compliance violation. Over-declaring costs a line on the
product page. Where the two are in tension the answer is the accurate one.

### Why "linked to the user"

The agent's Chatwoot user ID ties a device to a specific account holder. That
is the whole point of it: it is what lets the gateway alert only the agent a
conversation is assigned to. A device identifier stored beside a user
identifier is linked data.

### Why "not used for tracking"

Tracking means linking this data with data from other companies' apps or
websites for advertising or measurement, or sharing it with a data broker.
None of that happens. The identifiers exist only to route a notification.

### The manifest agrees

`WootDesk/Resources/PrivacyInfo.xcprivacy` declares the same two types with the
same purpose, linkage and tracking answers. The two must not diverge, and they
previously did: the manifest declared no collected data at all while the
gateway was already storing device tokens.

`NSPrivacyAccessedAPITypes` is correctly empty. The app uses no required-reason
API, verified by searching for `UserDefaults`, file timestamp, disk space and
system uptime APIs, none of which appear.

### Confirm before submitting

As Account Holder you should satisfy yourself this matches the shipping build
before publishing the answer. The facts above are drawn from the source and the
deployed gateway on 3 September 2026; if the gateway's retention, the enrolment
payload, or the set of linked services changes, revisit it.

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
