# WootDesk Push Gateway

The WootDesk Push Gateway is a dependency-free Node.js 22 service that converts
authenticated Chatwoot `message_created` webhooks into generic Apple Push
Notification service alerts. It is intended for an organisation-controlled or
self-hosted deployment behind an HTTPS reverse proxy.

This directory is a production-oriented foundation, not evidence of a deployed
service. Remote notification delivery remains unavailable until an operator has
configured Apple credentials, deployed the gateway, enrolled signed physical
devices, and completed the acceptance checks below.

## Security and privacy boundaries

The gateway:

- never requests, accepts, or stores a Chatwoot personal access token;
- requires a high-entropy secret in every Chatwoot webhook route;
- optionally verifies timestamped webhook HMAC signatures when a trustworthy
  signer supplies them;
- requires bearer authentication for every device registration mutation;
- encrypts APNs device tokens at rest with AES-256-GCM;
- stores only opaque device, profile, account, environment, and delivery
  routing values;
- accepts only new public incoming messages for notification delivery;
- sends a generic alert without the customer name or message body;
- never logs route secrets, device API tokens, APNs tokens, webhook bodies,
  customer identifiers, or request paths;
- removes a registration when APNs reports an invalid or unregistered token;
- persists idempotency state so a webhook retry skips devices already handled.

The first policy routes an event to every current registration for its Chatwoot
account. An organisation that requires per-agent routing must not deploy this
foundation until a separately reviewed recipient policy exists.

## Architecture

```text
Chatwoot account webhook
  -> HTTPS reverse proxy
  -> mandatory secret gateway route
  -> incoming-message and account policy
  -> APNs development or production endpoint
  -> WootDesk
```

The Node service deliberately listens with HTTP. TLS must terminate at a
trusted reverse proxy on the same host or private network. Production requests
are rejected unless the proxy supplies `X-Forwarded-Proto: https`. Do not expose
the Node listener directly. Bind it to loopback when the proxy runs on the same
host. For containers, use a private container network plus a host firewall.

`X-Forwarded-Proto` is trusted deployment metadata, not authentication. A
publicly reachable Node port would allow a client to forge it. The reverse proxy
must also suppress or redact access logging for the webhook path because that
path contains its mandatory secret. Gateway application logs use a fixed route
name and never record the path.

## Configuration

Configuration is read from environment variables and validated before the
listener starts. Placeholder values in `.env.example` are intentionally
invalid.

| Variable | Required | Meaning |
| --- | --- | --- |
| `NODE_ENV` | Yes | `production`, `development`, or `test` |
| `HOST` | No | Listener IP, default `127.0.0.1` |
| `PORT` | No | Listener port, default `8080` |
| `ALLOW_INSECURE_LOCAL_TEST` | No | Permits loopback HTTP only outside production |
| `DATA_FILE` | Yes | Atomic encrypted registration store path |
| `DATA_ENCRYPTION_KEY` | Yes | Unpadded base64url value decoding to exactly 32 bytes |
| `DEVICE_API_TOKEN` | Yes | Organisation bearer secret of at least 32 random bytes |
| `WEBHOOK_ROUTE_SECRET` | Yes | URL-safe route secret of at least 32 random bytes |
| `CHATWOOT_WEBHOOK_SIGNING_SECRET` | No | HMAC key of at least 32 random bytes |
| `CHATWOOT_SIGNATURE_TOLERANCE_SECONDS` | No | Timestamp window, default 300 seconds |
| `APNS_TEAM_ID` | Yes | Apple Developer team identifier |
| `APNS_KEY_ID` | Yes | APNs token signing key identifier |
| `APNS_PRIVATE_KEY_FILE` | Yes | Read-only mounted `.p8` key file |
| `APNS_BUNDLE_ID` | Yes | APNs topic, currently `dev.n85.wootdesk` |
| `MAX_BODY_BYTES` | No | Maximum JSON body, default 32,768 bytes |
| `REQUEST_TIMEOUT_MS` | No | HTTP and APNs timeout, default 10,000 ms |
| `RATE_LIMIT_WINDOW_MS` | No | In-memory rate limit window, default 60,000 ms |
| `DEVICE_RATE_LIMIT` | No | Device mutations per source and window, default 30 |
| `WEBHOOK_RATE_LIMIT` | No | Webhooks per source and window, default 300 |
| `IDEMPOTENCY_TTL_SECONDS` | No | Mutation and delivery record lifetime, default one day |
| `REGISTRATION_TTL_DAYS` | No | Inactive registration lifetime, default 90 days |
| `MAX_REGISTRATIONS_PER_EVENT` | No | Account fan-out safety limit, default 500 |
| `SHUTDOWN_GRACE_MS` | No | Shutdown deadline, default 10,000 ms |

Generate each secret independently. Do not paste the result into chat, source,
shell history, screenshots, CI output, or an image layer. One suitable local
generation command is:

```bash
openssl rand -base64 32 | tr '+/' '-_' | tr -d '=\n'
```

Store `DATA_ENCRYPTION_KEY`, `DEVICE_API_TOKEN`, `WEBHOOK_ROUTE_SECRET`, the
optional signing secret, and the Apple `.p8` key in the host's approved secret
manager. Back up the data encryption key separately. Losing it makes existing
device registrations unrecoverable. Rotating it requires controlled
re-encryption or re-enrolment. Never bake secrets into the Docker image.

## Device API contract

All device endpoints require:

```http
Authorization: Bearer <DEVICE_API_TOKEN>
Idempotency-Key: <16-to-128-safe-characters>
Content-Type: application/json
```

The future WootDesk client must keep the device API token in Apple Keychain.
The token is organisation-scoped in this foundation. The API never returns an
APNs token.

### Register a device

`POST /v1/devices`

```json
{
  "deviceId": "11111111-1111-4111-8111-111111111111",
  "profileId": "aaaaaaaa-aaaa-4aaa-8aaa-aaaaaaaaaaaa",
  "accountId": 42,
  "environment": "production",
  "topic": "dev.n85.wootdesk",
  "token": "<hexadecimal-apns-device-token>"
}
```

Success is `201 Created`:

```json
{
  "registration": {
    "deviceId": "11111111-1111-4111-8111-111111111111",
    "profileId": "aaaaaaaa-aaaa-4aaa-8aaa-aaaaaaaaaaaa",
    "accountId": 42,
    "environment": "production",
    "topic": "dev.n85.wootdesk",
    "updatedAt": "2026-08-31T12:00:00.000Z"
  }
}
```

### Update a rotated token or routing registration

`PUT /v1/devices/{deviceId}` uses the same body without `deviceId`. Success is
`200 OK` with the token-free registration response above. The update replaces
the prior token and routing metadata atomically.

### Remove a registration

`DELETE /v1/devices/{deviceId}` has no request body and returns `204 No Content`.
Deletion is idempotent. Repeating any successful mutation with the same key and
same canonical request returns the prior status with
`Idempotency-Replayed: true`. Reusing a key for different input returns `409`.

Errors use this envelope:

```json
{
  "error": {
    "code": "invalid_registration",
    "message": "The registration body has missing or unsupported fields."
  }
}
```

Expected status classes include `400`, `401`, `404`, `409`, `413`, `429`, and
`503`. A client must not treat an unknown response as success.

## Chatwoot webhook contract

Configure the Chatwoot account webhook for:

```text
https://push.example.invalid/v1/webhooks/chatwoot/<WEBHOOK_ROUTE_SECRET>
```

The route secret is mandatory even when HMAC verification is enabled. Use a
different secret for every deployment. Select the Chatwoot `message_created`
event. The gateway accepts only `message_type: "incoming"` (or the documented
integer value `0`) with an explicit `private: false`. Outgoing messages, private
notes, other events, and ambiguous privacy values are acknowledged and ignored.

`X-Chatwoot-Delivery` is used for idempotency when present. If it is absent, the
gateway derives a stable identifier from the account and message identifiers.
Only a hash of the delivery identifier is persisted.

### Optional signature adapter

Current Chatwoot account webhook signature availability and behaviour vary by
version and deployment. Some installations do not provide a usable signature.
For that reason, the high-entropy route secret is always required and HMAC
verification is optional. Do not configure
`CHATWOOT_WEBHOOK_SIGNING_SECRET` unless Chatwoot or a trusted ingress adapter
actually supplies both headers using this exact contract:

```text
X-Chatwoot-Timestamp: <ten-digit-Unix-seconds>
X-Chatwoot-Signature: sha256=<lowercase-hex-HMAC>
signed bytes: <timestamp>.<exact raw request body>
algorithm: HMAC-SHA256
```

When configured, a missing, malformed, stale, or invalid signature returns
`401`. The default timestamp tolerance is five minutes. The route secret is
still checked first.

The successful webhook response is `202 Accepted` with an `accepted`,
`duplicate`, or `ignored` status. A retryable APNs failure returns `502`; the
persisted delivery state ensures a retry skips devices already accepted or
invalidated.

## APNs behaviour

The provider uses Apple's HTTP/2 API and token authentication. ES256 signatures
use the required 64-byte P1363 representation. Development registrations route
to the APNs sandbox host. Production registrations route to the production
host. Provider JWTs are reused for no more than 50 minutes.

The notification contains only:

```json
{
  "aps": {
    "alert": {
      "title": "WootDesk",
      "body": "A new message was received."
    },
    "sound": "default"
  },
  "profile_id": "<opaque-profile-uuid>",
  "account_id": 42,
  "conversation_id": 700
}
```

Message bodies, contact names, email addresses, phone numbers, attachments, and
custom attributes are never copied to APNs or the registration store.

## Health and readiness

`GET /healthz` returns `200 {"status":"ok"}` when the process can answer.
`GET /readyz` returns `200 {"status":"ready"}` only when encrypted storage and
the APNs sender are ready, otherwise it returns `503`. Production probes must
reach these paths through the HTTPS proxy or supply trusted proxy metadata from
the private network.

## Build and run

Node.js 22 or later is required. No package installation is needed because the
gateway has no runtime or development dependencies.

```bash
cd Gateway
npm test
npm run check
node src/index.js
```

The included container can be built with:

```bash
docker build -t wootdesk-push-gateway:local Gateway
```

At runtime, mount the environment configuration outside the image, mount the
Apple `.p8` file read-only, and place `/data` on an encrypted persistent volume.
Run as the image's unprivileged `node` user. Configure backups for the encrypted
data file, limit access to the encryption key, and test restoration before
depending on the service.

## Verification and release gates

The test suite uses invented data, a temporary encrypted store, an injected APNs
sender, and an in-memory HTTP harness. It never opens a network listener or
contacts Chatwoot or Apple.

Before calling remote notifications available, an operator must separately:

1. enable Push Notifications for the explicit WootDesk App ID;
2. create the Apple APNs signing key through an approved account action;
3. provision secrets and deploy behind a hardened HTTPS reverse proxy;
4. ensure proxy, platform, and container logs redact the secret webhook path;
5. configure an invented-data Chatwoot account webhook;
6. enrol signed physical iPhone, iPad, and Mac builds;
7. prove development and production environment isolation;
8. prove incoming, outgoing, private-note, duplicate, token-rotation, deletion,
   invalid-token, rate-limit, timeout, and restart behaviour;
9. document retention, deletion, backup, restoration, incident response, key
   rotation, and operator access;
10. review App Store privacy answers against the actual deployment.

Do not place this service on the public internet until these controls and the
physical-device acceptance matrix have passed.
