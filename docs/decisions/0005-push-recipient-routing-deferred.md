# DEC-008: Defer per-agent push recipient routing until the policy is chosen

Document ID: `WOOT-DEC-0005`

Status: Deferred, with the gap recorded against N85-15 AC2

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

Do not implement per-agent routing yet.

1. **It needs a product decision, not an engineering guess.** Chatwoot's own
   model has an assignee, a team, and inbox membership. Whether an unassigned
   conversation should reach everyone, whether a team member should be
   notified alongside the assignee, and what happens when assignment changes
   mid-conversation are policy questions. Choosing wrong produces silent
   non-delivery, which in a support tool is worse than the current
   over-delivery.
2. **It cannot be verified end to end.** There is no deployed gateway, no Apple
   push credentials and no enrolled physical device. Shipping privacy-critical
   routing validated only by unit tests would repeat the failure mode this
   project has already hit three times: a green result that proves nothing.
3. **It changes an API contract.** Enrolment would gain an agent identifier,
   the stored registration schema would change, and any already-deployed
   gateway would need a migration with a defined meaning for existing rows.

## What implementing it would touch

Recorded so the estimate is not re-derived later:

- `Gateway/src/validation.js`: accept an optional agent identifier on create
  and update registration, and parse `conversation.meta.assignee.id` from the
  webhook.
- `Gateway/src/store.js`: persist the agent identifier and add a recipient
  query that filters by it.
- `Gateway/src/app.js`: select recipients through that query, falling back to
  account-wide when either side lacks identity so existing rows keep working.
- `Gateway/src/config.js`: a policy setting, so the choice is configurable
  rather than compiled in.
- The Swift gateway client: send the agent identifier at enrolment. The value
  is already available from `GET /api/v1/profile`.
- Tests on both sides, including the two-agents-one-account case that does not
  exist today.

## Consequence

N85-15 cannot be called source complete. AC2 is unmet and AC7 remains blocked
on deployment. `docs/PUSH_NOTIFICATIONS.md` already carries the correct
warning against deploying for an organisation that needs per-agent routing;
that warning stands.
