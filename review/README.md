# App Review Environment

A dedicated Chatwoot server at `https://review.n85.app` holding invented data
only, for Apple App Review.

## Why it exists

WootDesk cannot be assessed without a Chatwoot server. A reviewer given no
environment sees a setup screen and nothing else, which invites a Guideline 2.1
rejection for incompleteness. This stack must stay up for the whole review
window, including any re-review after a rejection.

## What a reviewer sees

| Item | Value |
|---|---|
| Server address | `https://review.n85.app` |
| Account | `WootDesk Demo Support`, account ID 1 |
| Agent | `Demo Agent`, administrator |
| Conversations | Three: two open, one resolved, so status filtering has something to show |
| Labels | `billing`, `export`, `engineering` |
| Messages | Each conversation has an incoming message, an agent reply, and a private note |

Every record is fictional. Contacts are `Avery Example`, `Blake Sample` and
`Casey Invented`, all on `example.invalid`, a domain that cannot receive mail.

## Credentials

Held in Infisical at `prod:/review`. Never commit them, and enter them only in
App Store Connect's private App Review fields.

| Secret | Purpose |
|---|---|
| `REVIEW_AGENT_EMAIL` | Chatwoot sign-in for the reviewer |
| `REVIEW_AGENT_PASSWORD` | Chatwoot sign-in for the reviewer |
| `REVIEW_ACCESS_TOKEN` | The token the reviewer pastes into WootDesk |

Retrieve one with:

```bash
infisical secrets get REVIEW_ACCESS_TOKEN --env=prod --path=/review --plain
```

## Operating it

The stack lives at `/opt/wootdesk-review` on the n85 VPS, published to
`127.0.0.1:8100` only, with the host's nginx terminating TLS. The certificate
renews through the host's existing certbot timer.

```bash
ssh n85 'cd /opt/wootdesk-review && docker compose ps'
ssh n85 'cd /opt/wootdesk-review && docker compose logs --tail 50 rails'
ssh n85 'cd /opt/wootdesk-review && docker compose restart rails sidekiq'
```

Account signup is disabled (`ENABLE_ACCOUNT_SIGNUP=false`), so the environment
cannot accumulate unexpected users while it is publicly reachable.

## Re-seeding

The seed is idempotent and safe to re-run. A reviewer may leave replies or
change conversation states, which is expected and harmless.

```bash
ssh n85 'cd /opt/wootdesk-review && docker compose exec -T \
  -e REVIEW_AGENT_EMAIL=... -e REVIEW_AGENT_PASSWORD=... \
  rails bundle exec rails runner /app/seed_review_data.rb'
```

## Before the review window closes

This environment is public. Once the review is finished and the app is
approved, tear it down rather than leaving it running:

```bash
ssh n85 'cd /opt/wootdesk-review && docker compose down -v'
```

Then remove the nginx site, the certificate, and the `review.n85.app` DNS
record.
