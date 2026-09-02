# Chatwoot Live Compatibility Testing

Status: Matrix run and passing against Chatwoot v4.9.0

Last reviewed: 1 September 2026

## Purpose

The normal WootDesk test suite is deterministic and never contacts a live
server. This separate opt-in harness checks WootDesk against supported Chatwoot
releases without placing a real server address, token, message, or customer
record in Git or CI output.

The harness covers:

- Personal access token validation through `GET /api/v1/profile`.
- Profile decoding for account-specific availability and auto-offline metadata.
- Account-scoped conversation decoding.
- Conversation message history decoding and stable identifiers.
- An outgoing public reply.
- A private internal note.
- A multipart text attachment and the returned attachment metadata.

## Dedicated-server requirements

Use a server created only for WootDesk acceptance. It must:

- Use HTTPS with system-trusted certificates.
- Contain invented accounts, agents, contacts, inboxes, conversations, messages,
  private notes, and attachments only.
- Have no webhook, email, social-channel, automation, or other integration that
  can contact a real person or production system.
- Provide a dedicated least-privilege agent and personal access token.
- Be resettable after mutating tests.
- Remain isolated from every production Chatwoot database and object store.

Suggested invented records include an account named `WootDesk Compatibility`, a
contact named `Avery Example`, and a conversation about a fictional sample
export. Do not copy records from a real server.

## Standing the server up

A reproducible stack is provided so the dedicated server does not have to be
built by hand. It runs a pinned Chatwoot release, Postgres with pgvector, Redis,
and Caddy for trusted HTTPS, and it is isolated from every production system.

```bash
script/compat_env.sh up
```

First boot runs migrations and takes several minutes. Then load the invented
records, which prints the account and conversation identifiers the checks need:

```bash
script/compat_env.sh seed
```

WootDesk requires system-trusted certificates, so trust Caddy's local
certificate authority once:

```bash
script/compat_env.sh trust
```

Destroy everything, including volumes, after a mutating run:

```bash
script/compat_env.sh reset
```

Pin the exact release in `compat/.env` through `CHATWOOT_VERSION`. Record that
tag in the supported-version matrix below. The seeded records are invented:
account `WootDesk Compatibility`, contact `Avery Example`, and a conversation
about a fictional sample export, with a public reply, a private note, and
labels the triage checks add to and remove from.

## Running read-only checks

Run the script interactively so the token is entered without being echoed:

```bash
./script/live_compatibility.sh
```

The script prompts for the HTTPS address, invented-data account ID, invented-data
conversation ID, and dedicated token. It does not print those values. The token
is copied into a permission-restricted temporary file, only that file path is
passed to XCTest, and the script deletes the exact temporary file on exit.
Read-only checks do not create messages.

For controlled CI outside the public repository, supply the non-secret values as
protected process environment variables and provide the token through
`WOOTDESK_LIVE_TOKEN_FILE`. The referenced file must be readable only by the test
runner and stored outside the repository. Never put a token in a checked-in
environment file, workflow, command example, screenshot, issue, or XCTest launch
environment.

## Running mutating checks

Mutating tests create one public reply, one private note, and one small text
attachment. They also write the agent's current availability back unchanged, and
they exercise every triage behaviour on the configured invented-data
conversation: a status change, a priority change, and one label added and then
removed. The triage checks record the conversation's status and priority before
they run and restore both afterwards, including when an assertion fails. They do
not delete or alter existing messages. Run them only after confirming the target
is the isolated invented-data server:

```bash
./script/live_compatibility.sh --allow-writes --confirm-invented-data
```

Both flags are mandatory. A coding agent must still receive explicit action-time
approval before it runs this command because it changes remote data.

## Environment verification, 1 September 2026

The stack was built from scratch, destroyed, and rebuilt to confirm it comes up
unattended. Two defects had to be fixed first, both of which failed silently:

| Defect | Effect | Fix |
|---|---|---|
| The compose stack never created the database schema | `rails` and `sidekiq` crash-looped on a fresh volume with `relation "installation_configs" does not exist`, while `compat_env.sh up` still exited 0 | One-shot `db-prepare` service running `db:chatwoot_prepare`, with both app services waiting on `service_completed_successfully` |
| The seed password used `SecureRandom.hex`, which has no uppercase or special character | Chatwoot 4.9 rejected the agent record, so the seed aborted | Password prefixed to satisfy the policy. It is never used; WootDesk authenticates with the access token |
| `live_compatibility.sh` exported `WOOTDESK_LIVE_*` into its own environment only | `xcodebuild` forwards only `TEST_RUNNER_`-prefixed variables, so all three cases skipped themselves and the script exited 0, which looked like a passing run that never contacted the server | The script now exports each setting under a `TEST_RUNNER_` prefix as well |

Verified against `chatwoot/chatwoot:v4.9.0` over the proxied HTTPS endpoint:

| Check | Result |
|---|---|
| `GET /api/v1/profile` | User 1, `Compatibility Agent`, account 1 `WootDesk Compatibility`, role `administrator` |
| `GET /api/v1/accounts/1/conversations?status=open` | One conversation, `open`, label `billing`, assigned to the agent |
| `GET /api/v1/accounts/1/conversations/1/messages` | 4 messages, of which 1 is a private note |
| `GET /api/v1/accounts/1/labels` | `billing`, `engineering`, `export` |

### Proxy header behaviour worth keeping

Through the Caddy proxy, a request carrying only `api_access_token` is rejected
with HTTP 401, while the same request carrying `api-access-token` succeeds.
Directly against Rails both spellings work, so the underscore form is lost in
proxying. WootDesk already sends both spellings from
`WootDesk/Core/API/APIRequest.swift`, which is why it is unaffected. This is
worth keeping in the record: it reproduces a real self-hosted deployment
hazard, and it independently confirms that defence is load-bearing rather than
decorative.

### Matrix run, 2 September 2026

All three cases passed against `chatwoot/chatwoot:v4.9.0` over the proxied
HTTPS endpoint, with both write gates set:

| Case | Result |
|---|---|
| `testProfileConversationListAndHistoryCompatibility` | Passed |
| `testPublicReplyPrivateNoteAndAttachmentCompatibility` | Passed |
| `testAvailabilityAndTriageCompatibility` | Passed |

The run is mutating, and the state it is expected to restore was restored:
status back to `open`, priority back to none, labels back to `billing`, and the
assignee unchanged. That confirms the suite's own restore path rather than
taking it on trust.

Messages are not restored, and should not be, because a reply cannot be
unsent. The seeded conversation grew from 4 messages to 13. Run
`script/compat_env.sh reset` to return the server to a clean seeded state
before recording another matrix run.

### Trusting the CA

The run requires Caddy's local certificate authority to be trusted, because
the tests deliberately construct the client with `isDebug: false` so that
production transport rules are what gets verified. Plain HTTP on localhost is
rejected by design, so this cannot be worked around in code.

```bash
script/compat_env.sh trust
```

That prints the two commands. The trust step needs `sudo` against the System
keychain. Remove it once the run is finished; the CA is generated locally by
the Caddy container and should not outlive the run.

## Supported-version matrix

Record evidence without credentials or message bodies:

| Chatwoot release | Deployment | Read-only | Public reply | Private note | Attachment | Availability | Triage | Date | Reviewer |
|---|---|---|---|---|---|---|---|---|---|
| `chatwoot/chatwoot:v4.9.0` | Dedicated container | Pass | Pass | Pass | Pass | Pass | Pass | 2 Sep 2026 | `script/live_compatibility.sh --allow-writes --confirm-invented-data`, 3 of 3 passed |
| Previous supported release | Dedicated container | Pending | Pending | Pending | Pending | Pending | Pending | | |

Pin exact Chatwoot image versions for each run. Do not use a floating `latest`
tag as compatibility evidence. Re-run the matrix before changing the documented
minimum supported Chatwoot release.

## Response differences handled by WootDesk

Current Chatwoot source accepts account-specific agent availability changes at
`POST /api/v1/profile/availability` using `online`, `busy`, or `offline`.
WootDesk sends those current values and does not retry the mutation
automatically. Profile responses using either `online` or the documented
`available` spelling map to Online. An unknown future spelling is treated as a
missing optional value, so it does not prevent profile validation or account
selection.

WootDesk accepts the current `{ "meta": ..., "payload": [...] }` message
envelope, a nested `data.payload` variant, and a direct array used by some older
self-hosted versions. Non-essential message and attachment fields are optional.
Attachment URLs are exposed to the user only when they are HTTPS, except for a
narrow debug-only localhost HTTP path. Unknown fields and attachment types are
preserved through tolerant fallbacks rather than causing a crash.

The official message-create endpoint accepts JSON for text-only messages and
`multipart/form-data` with `attachments[]` for file messages. WootDesk uses each
format only for its corresponding request and never retries a mutating request
automatically.

Chatwoot's triage endpoints differ in what they return. `toggle_priority` and
some `toggle_status` and `assignments` responses confirm with an empty body or
with only a fragment of the conversation. WootDesk therefore treats no triage
response body as authoritative: after every triage mutation it reads
`GET /api/v1/accounts/{account_id}/conversations/{conversation_id}` and displays
that result. A conversation payload that omits `labels`, `snoozed_until`,
`meta.assignee`, or `meta.team` is read as "not set" rather than as a fabricated
value.

`POST .../conversations/{id}/labels` replaces the whole label set rather than
merging it. WootDesk therefore reads the current set immediately before every
label change and sends the complete intended set, so a label another agent added
after the conversation was displayed is preserved.

Conversation label responses are accepted both as a payload of title strings and
as a payload of label objects, because supported versions differ. An agent-role
token is refused access to `GET /api/v1/accounts/{account_id}/teams` on supported
versions; WootDesk records that as "no teams available to this agent" and still
offers agent assignment, while any other team-list failure is reported.
