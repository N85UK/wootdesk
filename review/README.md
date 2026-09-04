# App Review Environment

A dedicated Chatwoot server at `https://review.n85.app` holding invented data
only, for Apple App Review.

## Why it exists

WootDesk cannot be assessed without a Chatwoot server. A reviewer given no
environment sees a setup screen and nothing else, which invites a Guideline 2.1
rejection for incompleteness. This stack must stay up for the whole review
window, including any re-review after a rejection.

## When to stop it

This environment is publicly reachable and runs an older Chatwoot than
production, so it should not be left up indefinitely after a release.

It should also not be stopped too early, and **"review completed" is the wrong
trigger**. A rejection means the environment is needed again for the
resubmission, so the condition is review *passed*, on every platform.

Rather than remember the rule, ask:

```bash
python3 script/review_env_status.py
```

It reads the live App Store state for both platforms and answers KEEP RUNNING
or SAFE TO STOP, printing the stop command when it is safe. It exits non-zero
whenever the answer is anything other than "safe", including when it cannot
reach App Store Connect or meets a state it does not recognise, so an
automated caller errs towards leaving the environment alone.

When it does say safe:

```bash
ssh <vps> 'cd <deploy-root>/wootdesk-review && docker compose stop'
```

Keep the DNS record and the certificate. Stopping the containers is enough,
and it can be restarted without re-issuing anything.

## The access-token header and nginx

Chatwoot authenticates with the header `api_access_token`. nginx drops header
names containing underscores unless `underscores_in_headers on` is set, so a
client sending only the documented header receives 401 and looks as though its
token has been revoked.

WootDesk sends both `api_access_token` and `api-access-token`, so the app was
never affected, which is exactly why this went unnoticed: everything that
mattered worked, and only a direct `curl` failed.

The directive is now set on the `review.n85.app` HTTPS server block, scoped to
that vhost rather than globally. Both forms return 200. If this environment is
ever rebuilt on a new host, the vhost needs it again.

```bash
# Both of these should return 200.
curl -o /dev/null -w '%{http_code}\n' -H "api_access_token: $TOKEN" https://review.n85.app/api/v1/profile
curl -o /dev/null -w '%{http_code}\n' -H "api-access-token: $TOKEN" https://review.n85.app/api/v1/profile
```

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

The stack lives at `<deploy-root>/wootdesk-review` on the deployment host, published to
`127.0.0.1:8100` only, with the host's nginx terminating TLS. The certificate
renews through the host's existing certbot timer.

```bash
ssh <vps> 'cd <deploy-root>/wootdesk-review && docker compose ps'
ssh <vps> 'cd <deploy-root>/wootdesk-review && docker compose logs --tail 50 rails'
ssh <vps> 'cd <deploy-root>/wootdesk-review && docker compose restart rails sidekiq'
```

Account signup is disabled (`ENABLE_ACCOUNT_SIGNUP=false`), so the environment
cannot accumulate unexpected users while it is publicly reachable.

## Re-seeding

The seed is idempotent and safe to re-run. A reviewer may leave replies or
change conversation states, which is expected and harmless.

```bash
ssh <vps> 'cd <deploy-root>/wootdesk-review && docker compose exec -T \
  -e REVIEW_AGENT_EMAIL=... -e REVIEW_AGENT_PASSWORD=... \
  rails bundle exec rails runner /app/seed_review_data.rb'
```

## Current state: stopped

The containers are **stopped**, so `https://review.n85.app` returns 502. DNS,
the nginx site, the Let's Encrypt certificate and all three data volumes are
kept, so restarting restores the same account, the same seeded conversations
and, importantly, the **same access token**. Nothing in App Store Connect needs
re-entering.

```bash
ssh <vps> 'cd <deploy-root>/wootdesk-review && docker compose start'
```

Allow about forty seconds for Chatwoot to answer, then confirm:

```bash
curl -s -o /dev/null -w "%{http_code}\n" https://review.n85.app/
```

**Start it before submitting for App Review.** The review notes in App Store
Connect name this address, and a reviewer who cannot reach it will reject the
app as non-functional under Guideline 2.1, which is the outcome this
environment exists to prevent.

## Before the review window closes

This environment is public. Once the review is finished and the app is
approved, tear it down rather than leaving it running:

```bash
ssh <vps> 'cd <deploy-root>/wootdesk-review && docker compose down -v'
```

Then remove the nginx site, the certificate, and the `review.n85.app` DNS
record.
