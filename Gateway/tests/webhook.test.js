import assert from "node:assert/strict"
import { createHmac, randomBytes } from "node:crypto"
import test from "node:test"
import {
  createDevice,
  createHarness,
  incomingMessage,
  profileID,
  registration,
  secondDeviceID,
  secondProfileID,
} from "./helpers.js"

async function sendWebhook(harness, body, headers = {}) {
  return harness.request(
    `/v1/webhooks/chatwoot/${harness.config.webhookRouteSecret}`,
    {
      method: "POST",
      headers: { "content-type": "application/json", ...headers },
      body: typeof body === "string" ? body : JSON.stringify(body),
    },
  )
}

test("only incoming public messages produce a generic account-routed alert", async (t) => {
  const harness = await createHarness()
  t.after(() => harness.close())
  await createDevice(
    harness,
    registration({ environment: "production" }),
    "create-primary-0001",
  )
  await createDevice(
    harness,
    registration({
      deviceId: secondDeviceID,
      profileId: secondProfileID,
      accountId: 77,
      token: "cd".repeat(32),
    }),
    "create-secondary-001",
  )

  const response = await sendWebhook(harness, incomingMessage(), {
    "x-chatwoot-delivery": "invented-delivery-001",
  })
  assert.equal(response.status, 202)
  assert.equal(harness.calls.length, 1)
  assert.equal(harness.calls[0].item.accountId, 42)
  assert.equal(harness.calls[0].item.environment, "production")
  assert.deepEqual(harness.calls[0].payload, {
    aps: {
      alert: { title: "WootDesk", body: "A new message was received." },
      sound: "default",
    },
    profile_id: "aaaaaaaa-aaaa-4aaa-8aaa-aaaaaaaaaaaa",
    account_id: 42,
    conversation_id: 700,
  })
  const serialised = JSON.stringify(harness.calls[0].payload)
  assert.equal(serialised.includes("Invented customer"), false)
  assert.equal(serialised.includes("person@example.invalid"), false)
  assert.equal(JSON.stringify(harness.logs).includes("Invented Contact"), false)

  const outgoing = await sendWebhook(
    harness,
    incomingMessage({ id: 501, message_type: "outgoing" }),
  )
  assert.equal(outgoing.status, 202)
  const privateNote = await sendWebhook(
    harness,
    incomingMessage({ id: 502, private: true }),
  )
  assert.equal(privateNote.status, 202)
  assert.equal(harness.calls.length, 1)
})

test("webhook delivery resumes only failed devices", async (t) => {
  let attempts = 0
  const harness = await createHarness({
    send: async () => {
      attempts += 1
      if (attempts === 1) {
        return { accepted: false, invalidToken: false, status: 503 }
      }
      return { accepted: true, invalidToken: false, status: 200 }
    },
  })
  t.after(() => harness.close())
  await createDevice(harness)
  const headers = { "x-chatwoot-delivery": "retry-delivery-0001" }

  const failed = await sendWebhook(harness, incomingMessage(), headers)
  assert.equal(failed.status, 502)
  const retried = await sendWebhook(harness, incomingMessage(), headers)
  assert.equal(retried.status, 202)
  const duplicate = await sendWebhook(harness, incomingMessage(), headers)
  assert.equal(duplicate.status, 202)
  assert.equal((await duplicate.json()).status, "duplicate")
  assert.equal(attempts, 2)
})

test("APNs invalid tokens are removed without affecting a rotated token", async (t) => {
  const harness = await createHarness({
    send: async () => ({ accepted: false, invalidToken: true, status: 410 }),
  })
  t.after(() => harness.close())
  await createDevice(harness)
  const response = await sendWebhook(harness, incomingMessage())
  assert.equal(response.status, 202)
  assert.equal((await response.json()).invalidated, 1)
  assert.equal((await harness.store.registrationsForAccount(42, 90)).length, 0)
})

test("configured timestamped webhook signatures are verified", async (t) => {
  const signingKey = randomBytes(32)
  const harness = await createHarness({
    signingSecret: signingKey.toString("base64url"),
  })
  t.after(() => harness.close())
  const body = JSON.stringify(incomingMessage())
  const timestamp = String(Math.floor(Date.now() / 1000))
  const signature = createHmac("sha256", signingKey)
    .update(Buffer.from(`${timestamp}.${body}`, "utf8"))
    .digest("hex")

  const accepted = await sendWebhook(harness, body, {
    "x-chatwoot-timestamp": timestamp,
    "x-chatwoot-signature": `sha256=${signature}`,
  })
  assert.equal(accepted.status, 202)

  const rejected = await sendWebhook(
    harness,
    JSON.stringify(incomingMessage({ id: 501 })),
    {
      "x-chatwoot-timestamp": timestamp,
      "x-chatwoot-signature": `sha256=${signature}`,
    },
  )
  assert.equal(rejected.status, 401)
})

test("a wrong route secret is indistinguishable from a missing route", async (t) => {
  const harness = await createHarness()
  t.after(() => harness.close())
  const response = await harness.request(
    `/v1/webhooks/chatwoot/${randomBytes(32).toString("base64url")}`,
    {
      method: "POST",
      headers: { "content-type": "application/json" },
      body: JSON.stringify(incomingMessage()),
    },
  )
  assert.equal(response.status, 404)
})

test("an assigned conversation reaches only the assignee's devices", async (t) => {
  // N85-15 AC2. The pre-existing two-device test enrols its second device on
  // account 77, so it proves account isolation and says nothing about two
  // agents sharing one account, which is the case this covers.
  const harness = await createHarness()
  t.after(() => harness.close())

  await createDevice(
    harness,
    registration({ agentId: 1, environment: "production" }),
    "assignee-device-0001",
  )
  await createDevice(
    harness,
    registration({
      deviceId: secondDeviceID,
      profileId: secondProfileID,
      agentId: 2,
      environment: "production",
      token: "cd".repeat(32),
    }),
    "colleague-device-001",
  )

  const response = await sendWebhook(
    harness,
    incomingMessage({
      id: 900,
      conversation: { id: 700, meta: { assignee: { id: 1 } } },
    }),
    { "x-chatwoot-delivery": "assigned-delivery-01" },
  )

  assert.equal(response.status, 202)
  assert.equal(harness.calls.length, 1)
  assert.equal(harness.calls[0].item.agentId, 1)
  assert.equal(harness.calls[0].item.profileId, profileID)
})

test("an unassigned conversation reaches every agent on the account", async (t) => {
  // The chosen fallback, matching how Chatwoot treats an unassigned
  // conversation. Without it an unassigned message would reach nobody, which
  // is worse in a support tool than notifying too many people.
  const harness = await createHarness()
  t.after(() => harness.close())

  await createDevice(
    harness,
    registration({ agentId: 1, environment: "production" }),
    "unassigned-device-01",
  )
  await createDevice(
    harness,
    registration({
      deviceId: secondDeviceID,
      profileId: secondProfileID,
      agentId: 2,
      environment: "production",
      token: "cd".repeat(32),
    }),
    "unassigned-device-02",
  )

  const response = await sendWebhook(
    harness,
    incomingMessage({ id: 901, conversation: { id: 701 } }),
    { "x-chatwoot-delivery": "unassigned-delivery" },
  )

  assert.equal(response.status, 202)
  assert.equal(harness.calls.length, 2)
  assert.deepEqual(
    harness.calls.map((call) => call.item.agentId).sort(),
    [1, 2],
  )
})

test("a registration without an agent identity is excluded and reported", async (t) => {
  // A client built before per-agent routing still enrols, because rejecting it
  // would break setup outright. It cannot be matched to an assignee, so it is
  // excluded rather than notified about a colleague's conversation, and the
  // gateway says so instead of dropping it silently.
  const harness = await createHarness()
  t.after(() => harness.close())

  await createDevice(
    harness,
    registration({ environment: "production" }),
    "legacy-device-00001",
  )

  const response = await sendWebhook(
    harness,
    incomingMessage({
      id: 902,
      conversation: { id: 702, meta: { assignee: { id: 1 } } },
    }),
    { "x-chatwoot-delivery": "legacy-delivery-001" },
  )

  assert.equal(response.status, 202)
  assert.equal(harness.calls.length, 0)
  const reported = harness.logs.some(
    (entry) => entry.context?.deliveryOutcome === "unroutable_registrations",
  )
  assert.equal(reported, true)
})

test("assignee_id is accepted as an alternative payload shape", async (t) => {
  // Chatwoot spells the assignee differently between payload shapes, and
  // reading only one of them would silently fall back to notifying everybody.
  const harness = await createHarness()
  t.after(() => harness.close())

  await createDevice(
    harness,
    registration({ agentId: 5, environment: "production" }),
    "alt-shape-device-01",
  )
  await createDevice(
    harness,
    registration({
      deviceId: secondDeviceID,
      profileId: secondProfileID,
      agentId: 6,
      environment: "production",
      token: "cd".repeat(32),
    }),
    "alt-shape-device-02",
  )

  const response = await sendWebhook(
    harness,
    incomingMessage({
      id: 903,
      conversation: { id: 703, assignee_id: 5 },
    }),
    { "x-chatwoot-delivery": "alt-shape-delivery" },
  )

  assert.equal(response.status, 202)
  assert.equal(harness.calls.length, 1)
  assert.equal(harness.calls[0].item.agentId, 5)
})
