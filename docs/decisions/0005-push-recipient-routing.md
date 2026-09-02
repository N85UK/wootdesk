# DEC-008: Route push notifications to the assignee, falling back to all agents

Document ID: `WOOT-DEC-0005`

Status: Accepted and implemented

Date: 2 September 2026

## Context

N85-15 AC2 requires that when a conversation event targets one agent, only
devices registered to that agent receive the notification. The epic recorded
N85-15 as "source complete, AC7 needs deployment, credentials and devices",
which is wrong: AC2 is unimplemented in source, not blocked on deployment.

Four independent confirmations:

| Evidence | Detail |
|---|---|
| `Gateway/src/app.js` | `deliverEvent` selects recipients with `store.registrationsForAccount(event.accountId, ...)`, so every device enrolled for the account receives the alert |
| `Gateway/src/validation.js` | `validateWebhook` returns only `accountId`, `conversationId` and `messageId`. The assignee is never parsed |
| `Gateway/src/validation.js` | `validateCreateRegistration` uses `exactKeys` over `deviceId`, `profileId`, `accountId`, `environment`, `topic`, `token`. No agent identity is accepted or stored |
| `docs/PUSH_NOTIFICATIONS.md` | States plainly that the policy "notifies every enrolled device registered for the event's Chatwoot account" and "does not yet prove which Chatwoot agent should receive an event" |

The existing gateway test that enrols two devices proves **account** isolation,
because its second device is registered to account 77. No test covers two
agents on one account.

## Scope of the exposure

Narrower than "another agent can read a colleague's conversations". The payload
is generic and carries no message content:

```json
{ "aps": { "alert": { "title": "WootDesk", "body": "A new message was received." } },
  "profile_id": "...", "account_id": 42, "conversation_id": 700 }
```

AC5, which requires notification content to be minimised, is met. What leaks is
**activity metadata**: an agent learns that a message arrived and the
conversation identifier it belongs to. Opening it still requires that agent's
own token, and Chatwoot authorises access server-side.

So this is a real AC2 failure and a genuine privacy concern for shared
accounts, but it is not a content disclosure.

## Decision

**An assigned conversation notifies only the assignee's devices. An unassigned
conversation notifies every agent on the account.**

The fallback matters as much as the rule. Assignee-only with no fallback would
mean an unassigned conversation notifies nobody, and silent non-delivery in a
support tool is worse than notifying too many people. This also matches how
Chatwoot itself treats an unassigned conversation.

Alternatives considered and rejected: assignee-only, which has the
non-delivery problem above; and assignee plus their team, which is closer to
how shared inboxes are worked in practice but needs team membership the
gateway does not currently receive. The second remains open as a later change,
and the implementation below leaves room for it.

## Implementation

| Area | Change |
|---|---|
| `Gateway/src/validation.js` | Parses the assignee from all three shapes Chatwoot uses: `conversation.meta.assignee.id`, `conversation.assignee_id`, `conversation.assignee.id`. Reading only one would silently fall back to notifying everybody |
| `Gateway/src/validation.js` | Accepts an optional `agentId` on registration. `exactKeys` now separates required from optional keys |
| `Gateway/src/store.js` | Persists `agentId` and adds `registrationsForEvent`, which filters by assignee and reports registrations that carry no agent identity |
| `Gateway/src/app.js` | Selects recipients through that query and logs any unroutable registrations |
| `ServerProfile` | Gains `agentID: Int?`. Optional so profiles saved before this change decode rather than fail |
| `ChatwootAPIProtocol.fetchProfile` | Returns the agent identity, which `GET /api/v1/profile` already supplied and the client previously discarded |
| Connection add and edit flows | Thread the identity from validation to the saved profile. Editing refreshes it, because a changed token can authenticate a different user and a stale identity would route to the wrong person |
| `PushGatewayDeviceRegistrationRequest` | Carries `agentId`, omitted from the encoded body when absent |

### Registrations without an agent identity

They enrol successfully, because rejecting them would break setup outright.
They can never match an assigned conversation, so they are excluded rather
than notified about a colleague's conversation, and the gateway logs
`unroutable_registrations` with a count. A visible gap is easier to diagnose
than a silent one.

Because the client and gateway ship from this repository together, there is no
window in which a deployed gateway sees only identity-less registrations.

### Coverage

Gateway tests move from 18 to 22, adding the two-agents-one-account case that
did not previously exist, the unassigned fallback, the excluded-and-reported
path, and the alternative `assignee_id` payload shape. Swift tests move from
194 to 196, covering enrolment with and without an agent identity.

## Consequence

N85-15 AC2 is met in source. AC7 remains blocked on gateway deployment, Apple
push credentials and physical devices, and none of this has been exercised
against a real APNs delivery. The routing is proven by unit tests only, so it
still needs physical-device acceptance before it can be called done.
