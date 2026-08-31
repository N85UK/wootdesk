# Chatwoot Live Compatibility Testing

Status: Harness available, dedicated-server execution pending

Last reviewed: 31 August 2026

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
attachment. They do not delete or alter existing messages. Run them only after
confirming the target is the isolated invented-data server:

```bash
./script/live_compatibility.sh --allow-writes --confirm-invented-data
```

Both flags are mandatory. A coding agent must still receive explicit action-time
approval before it runs this command because it changes remote data.

## Supported-version matrix

Record evidence without credentials or message bodies:

| Chatwoot release | Deployment | Read-only | Public reply | Private note | Attachment | Date | Reviewer |
|---|---|---|---|---|---|---|---|
| Current supported release | Dedicated container | Pending | Pending | Pending | Pending | | |
| Previous supported release | Dedicated container | Pending | Pending | Pending | Pending | | |

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
