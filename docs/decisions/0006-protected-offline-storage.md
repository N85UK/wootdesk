# ADR 0006: Protected Offline Storage and Uncertain Send Representation

## Context

N85-16 asks for conversation work to survive network interruptions: an unsent
draft must come back, previously loaded content must remain readable while
offline, and an interrupted send must not be reported as either success or
plain failure.

Three constraints shaped the design.

1. WootDesk holds another organisation's customer conversations. Anything
   written to the device widens what a lost or seized device exposes.
2. Chatwoot's message creation endpoint accepts no idempotency key. A replayed
   request can post the same reply to a customer twice, and Chatwoot will not
   deduplicate it.
3. REST remains the source of truth. WootDesk must never present stored content
   as though it were current.

## Decision

**Storage.** Offline records are JSON files under
`Application Support/WootDesk/Offline/<profile UUID>/`, one file per
conversation, holding the draft, the last cached message page and any
unconfirmed-send records together. Writes are atomic. On iOS the files use the
`completeFileProtectionUntilFirstUserAuthentication` class, matching the
Keychain accessibility already used for the access token; macOS relies on
FileVault, which has no per-file equivalent. The directory is excluded from
device backups.

**Isolation.** Every record is filed under a `ConversationScope` of profile,
account and conversation. Nothing is read or written without one, so switching
server profile cannot surface another profile's drafts or messages.

**Deletion.** Emptying a draft deletes its record rather than storing blank
text. Sending deletes the draft. Removing a profile deletes its whole
directory. Switching offline storage off deletes the records for every known
profile.

**Optionality.** Offline storage is a setting. `ToggleableOfflineStore` applies
it, so with the setting off every read returns nothing and every write is
discarded, and the rest of the app needs no conditional paths.

**Uncertain sends.** A failed send is classified by whether the server may
still have applied it. `timedOut`, `networkError` and `decodingError`, and the
proxy-emitted 502, 503 and 504, are treated as uncertain; `offline`,
`unauthorized`, `forbidden`, `tlsFailure` and a plain 500 are treated as
definitely not applied. An uncertain send is recorded and the agent is warned
before any retry.

**Attachments.** A deny-list of directly executable and script file extensions
is refused at selection, before the file is read into memory.

## Alternatives rejected

**SwiftData persistent caching**, as sketched for Milestone 5. It brings a
schema, a migration story and a query layer for a feature whose whole job is to
hold a handful of records per conversation. Milestone 5 can still adopt it when
a synchronising cache is actually built.

**An automatic outgoing mutation queue.** This is the obvious reading of
"continue after connectivity returns", and it is the wrong one here. Without an
idempotency key, replaying a create is how the same reply reaches a customer
twice. Recording the uncertainty and asking the agent is the only behaviour
that cannot duplicate a customer-visible message. This is why AC3 is written as
representation rather than recovery.

**Conforming the domain models to `Codable` for the cache.** A stored file is
untrusted input: it can be edited, restored from a backup or written by an
older build. The cache keeps its own representation and re-validates on read,
so a tampered file cannot widen behaviour. In particular, attachment URLs are
put back through the same HTTPS-only check the API responses go through, and a
cache edited to carry an `http://` or `file://` URL yields no URL at all.

## Consequences

- A lost device with offline storage enabled exposes drafts and previously
  loaded messages for any profile still on it, protected at rest and, on iOS,
  encrypted until first unlock after boot.
- An agent who wants none of that can switch it off, and doing so deletes what
  was already stored.
- An interrupted send leaves the agent with a decision to make rather than an
  automatic outcome. This is deliberate: the alternative risks a duplicate
  message to a customer.
- A damaged record is discarded rather than preserved as a recovery copy, which
  differs from the profile-metadata handling. Cached pages are rebuildable from
  the server, and an unreadable draft cannot be recovered anyway, so keeping a
  corrupt file holding message content buys nothing.
