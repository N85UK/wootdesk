import assert from "node:assert/strict"
import { createHmac, randomBytes } from "node:crypto"
import test from "node:test"
import { createHarness, deviceID, profileID, registration, secondDeviceID, secondProfileID } from "./helpers.js"

/**
 * N85-64. Notifications must reach only the deployment whose event produced
 * them.
 *
 * The defect these cover: the gateway selected recipients by Chatwoot account
 * id and agent id alone. An account number is unique only within one Chatwoot,
 * so two deployments that both have an account numbered 1 shared a routing
 * namespace, and an event from one could notify devices enrolled against the
 * other. That is not hypothetical here: the production Chatwoot and the App
 * Review environment both have an account 1.
 *
 * These run the real HTTP handler and the real store against a fake APNs
 * sender, so they can assert exactly which devices were sent to. That is
 * stronger than a unit test, which cannot show a device was not notified, but
 * it is still not a real APNs delivery.
 */

const REVIEW = {
  id: "review",
  baseUrl: "https://review.invalid",
}

/** Both deployments have an account numbered 1, which is the whole point. */
const SHARED_ACCOUNT = 1

function incomingMessage({ id = 900, conversationId = 700, assigneeId } = {}) {
  return {
    event: "message_created",
    message_type: "incoming",
    private: false,
    id,
    account: { id: SHARED_ACCOUNT },
    conversation: {
      id: conversationId,
      meta: assigneeId === undefined ? {} : { assignee: { id: assigneeId } },
    },
  }
}

async function enrol(harness, body, { deviceId = deviceID, key } = {}) {
  return harness.request("/v1/devices", {
    method: "POST",
    headers: {
      "content-type": "application/json",
      authorization: `Bearer ${harness.config.deviceAPIToken}`,
      "idempotency-key": key ?? `enrol-${deviceId}`,
    },
    body: JSON.stringify({ ...registration({ deviceId, accountId: SHARED_ACCOUNT }), ...body }),
  })
}

async function sendWebhook(harness, routeSecret, body, headers = {}) {
  return harness.request(`/v1/webhooks/chatwoot/${routeSecret}`, {
    method: "POST",
    headers: { "content-type": "application/json", ...headers },
    body: typeof body === "string" ? body : JSON.stringify(body),
  })
}

test("AC1: an event does not notify a device enrolled against another deployment", async (t) => {
  const harness = await createHarness({ extraDeployments: [REVIEW] })
  t.after(() => harness.close())
  const [production, review] = harness.deployments

  // One device, enrolled against the review deployment only.
  const enrolled = await enrol(harness, { baseUrl: REVIEW.baseUrl, agentId: 7 })
  assert.equal(enrolled.status, 201)

  // The production Chatwoot, which also has an account 1, reports a message
  // assigned to agent 7. Same account number, same agent number, different
  // server.
  const response = await sendWebhook(
    harness,
    production.routeSecret,
    incomingMessage({ assigneeId: 7 }),
    { "x-chatwoot-delivery": "cross-deployment-1" },
  )

  assert.equal(response.status, 202)
  assert.equal((await response.json()).delivered, 0)
  assert.equal(harness.calls.length, 0, "a device enrolled elsewhere was notified")

  // AC1 also asks that the gateway records the event matching no registration
  // for that deployment.
  const recorded = harness.logs.find(
    (entry) => entry.context?.deliveryOutcome === "other_deployment_registrations",
  )
  assert.ok(recorded, "the skipped registration was not recorded")
  assert.equal(recorded.context.count, 1)
  assert.equal(recorded.context.deploymentId, production.id)
  assert.notEqual(review.routeSecret, production.routeSecret)
})

test("AC2: routing within a deployment is unchanged, including per-agent isolation", async (t) => {
  const harness = await createHarness({ extraDeployments: [REVIEW] })
  t.after(() => harness.close())
  const [production] = harness.deployments

  // The assignee, on production.
  await enrol(harness, { baseUrl: "https://chat.invalid", agentId: 7 })
  // A different agent on the same deployment and account.
  await enrol(
    harness,
    { baseUrl: "https://chat.invalid", agentId: 9, profileId: secondProfileID },
    { deviceId: secondDeviceID, key: "enrol-other-agent" },
  )
  // The same agent number, on the other deployment.
  await enrol(
    harness,
    { baseUrl: REVIEW.baseUrl, agentId: 7, profileId: profileID },
    { deviceId: "33333333-3333-4333-8333-333333333333", key: "enrol-review" },
  )

  const response = await sendWebhook(
    harness,
    production.routeSecret,
    incomingMessage({ assigneeId: 7 }),
    { "x-chatwoot-delivery": "same-deployment-1" },
  )

  assert.equal(response.status, 202)
  assert.equal((await response.json()).delivered, 1)
  assert.deepEqual(
    harness.calls.map((call) => call.item.deviceId),
    [deviceID],
    "delivery reached the wrong set of devices",
  )
})

test("AC3: a payload signed by one deployment is rejected on another's endpoint", async (t) => {
  const productionSecret = randomBytes(24).toString("base64url")
  const reviewSecret = randomBytes(24).toString("base64url")
  const harness = await createHarness({
    signingSecret: productionSecret,
    extraDeployments: [{ ...REVIEW, signingSecret: reviewSecret }],
  })
  t.after(() => harness.close())
  const [production, review] = harness.deployments

  const body = JSON.stringify(incomingMessage({ assigneeId: 7 }))
  const timestamp = String(Math.floor(Date.now() / 1000))
  const signWith = (secret) =>
    `sha256=${createHmac("sha256", secret).update(Buffer.from(`${timestamp}.${body}`, "utf8")).digest("hex")}`

  // Correctly signed for production, sent to production.
  const accepted = await sendWebhook(harness, production.routeSecret, body, {
    "x-chatwoot-timestamp": timestamp,
    "x-chatwoot-signature": signWith(productionSecret),
    "x-chatwoot-delivery": "signed-correctly",
  })
  assert.equal(accepted.status, 202)

  // The same payload, signed with production's secret, offered on review's
  // endpoint. Each deployment verifies with its own secret, so this fails.
  const rejected = await sendWebhook(harness, review.routeSecret, body, {
    "x-chatwoot-timestamp": timestamp,
    "x-chatwoot-signature": signWith(productionSecret),
    "x-chatwoot-delivery": "signed-for-the-other-one",
  })
  assert.equal(rejected.status, 401)
})

test("AC4: enrolment records the deployment the profile belongs to", async (t) => {
  const harness = await createHarness({ extraDeployments: [REVIEW] })
  t.after(() => harness.close())

  const created = await enrol(harness, { baseUrl: REVIEW.baseUrl, agentId: 7 })
  assert.equal(created.status, 201)

  const stored = await harness.store.registrationsForEvent(
    "review",
    SHARED_ACCOUNT,
    7,
    90,
  )
  assert.equal(stored.recipients.length, 1)
  assert.equal(stored.recipients[0].deviceId, deviceID)

  // And it is absent from the other deployment's view of the same account.
  const other = await harness.store.registrationsForEvent("default", SHARED_ACCOUNT, 7, 90)
  assert.equal(other.recipients.length, 0)
  assert.equal(other.otherDeployments, 1)
})

test("AC4: enrolment for an unknown server is refused with a reason", async (t) => {
  const harness = await createHarness({ extraDeployments: [REVIEW] })
  t.after(() => harness.close())

  const response = await enrol(harness, { baseUrl: "https://elsewhere.invalid", agentId: 7 })
  assert.equal(response.status, 400)
  const failure = (await response.json()).error
  assert.equal(failure.code, "unknown_deployment")
  assert.match(failure.message, /no configuration for that Chatwoot server/i)
})

test("AC4: enrolment without a server is refused when it would be ambiguous", async (t) => {
  const harness = await createHarness({ extraDeployments: [REVIEW] })
  t.after(() => harness.close())

  const response = await enrol(harness, { agentId: 7 })
  assert.equal(response.status, 400)
  assert.equal((await response.json()).error.code, "deployment_required")
})

test("AC4: enrolment without a server still works when there is only one", async (t) => {
  // A client built before this change must keep working against a gateway
  // serving a single Chatwoot, which is every gateway today.
  const harness = await createHarness()
  t.after(() => harness.close())

  const response = await enrol(harness, { agentId: 7 })
  assert.equal(response.status, 201)

  const stored = await harness.store.registrationsForEvent("default", SHARED_ACCOUNT, 7, 90)
  assert.equal(stored.recipients.length, 1)
})

test("AC5: a registration from before this change is attributed to the only deployment", async (t) => {
  const harness = await createHarness({
    seedRegistrations: [
      {
        deviceId: deviceID,
        profileId: profileID,
        accountId: SHARED_ACCOUNT,
        agentId: 7,
        environment: "development",
        topic: "dev.n85.wootdesk",
        createdAt: new Date().toISOString(),
        updatedAt: new Date().toISOString(),
        token: "cd".repeat(32),
      },
    ],
  })
  t.after(() => harness.close())

  const stored = await harness.store.registrationsForEvent("default", SHARED_ACCOUNT, 7, 90)
  assert.equal(stored.recipients.length, 1, "the legacy registration was not attributed")

  const recorded = harness.logs.find((entry) =>
    entry.message.includes("attributed to the only configured deployment"),
  )
  assert.ok(recorded, "the attribution was not recorded")
  assert.equal(recorded.context.count, 1)
})

test("AC5: a registration from before this change is never routed when it cannot be attributed", async (t) => {
  const harness = await createHarness({
    extraDeployments: [REVIEW],
    seedRegistrations: [
      {
        deviceId: deviceID,
        profileId: profileID,
        accountId: SHARED_ACCOUNT,
        agentId: 7,
        environment: "development",
        topic: "dev.n85.wootdesk",
        createdAt: new Date().toISOString(),
        updatedAt: new Date().toISOString(),
        token: "cd".repeat(32),
      },
    ],
  })
  t.after(() => harness.close())

  // Neither deployment may claim it. Guessing would notify a device about a
  // Chatwoot it never enrolled against, which is the defect this closes.
  for (const id of ["default", "review"]) {
    const stored = await harness.store.registrationsForEvent(id, SHARED_ACCOUNT, 7, 90)
    assert.equal(stored.recipients.length, 0, `${id} claimed an unattributed registration`)
  }

  const recorded = harness.logs.find((entry) =>
    entry.message.includes("were not attributed"),
  )
  assert.ok(recorded, "the operator was not told")
  assert.match(recorded.context.remedy, /enrol again/i)
})

test("AC6: a webhook for an unconfigured deployment is refused and recorded", async (t) => {
  const harness = await createHarness({ extraDeployments: [REVIEW] })
  t.after(() => harness.close())

  await enrol(harness, { baseUrl: REVIEW.baseUrl, agentId: 7 })

  const response = await sendWebhook(
    harness,
    randomBytes(32).toString("base64url"),
    incomingMessage({ assigneeId: 7 }),
    { "x-chatwoot-delivery": "unconfigured-1" },
  )

  // Indistinguishable from any other unmatched route, so an attacker probing
  // for a valid endpoint learns nothing from the response.
  assert.equal(response.status, 404)
  assert.equal(harness.calls.length, 0)

  const recorded = harness.logs.find(
    (entry) => entry.context?.deliveryOutcome === "unknown_deployment",
  )
  assert.ok(recorded, "the rejected webhook was not recorded")
})

test("an update carries the agent identity, which the app previously omitted", async (t) => {
  // Not strictly N85-64, but found while adding baseUrl to the same request.
  // The gateway requires agentId on update; the app's update body did not
  // include it, so every refresh was refused with 400 and a device could
  // enrol but never rotate its APNs token. This pins the requirement so the
  // omission cannot come back silently.
  const harness = await createHarness()
  t.after(() => harness.close())

  await enrol(harness, { agentId: 7 })

  const withoutAgent = await harness.request(`/v1/devices/${deviceID}`, {
    method: "PUT",
    headers: {
      "content-type": "application/json",
      authorization: `Bearer ${harness.config.deviceAPIToken}`,
      "idempotency-key": "update-without-agent",
    },
    body: JSON.stringify({
      profileId: profileID,
      accountId: SHARED_ACCOUNT,
      environment: "development",
      topic: "dev.n85.wootdesk",
      token: "ef".repeat(32),
    }),
  })
  assert.equal(withoutAgent.status, 400)

  const withAgent = await harness.request(`/v1/devices/${deviceID}`, {
    method: "PUT",
    headers: {
      "content-type": "application/json",
      authorization: `Bearer ${harness.config.deviceAPIToken}`,
      "idempotency-key": "update-with-agent",
    },
    body: JSON.stringify({
      profileId: profileID,
      accountId: SHARED_ACCOUNT,
      agentId: 7,
      environment: "development",
      topic: "dev.n85.wootdesk",
      token: "ef".repeat(32),
      baseUrl: "https://chat.invalid",
    }),
  })
  assert.equal(withAgent.status, 200)

  // The rotated token still routes, and still only to its own deployment.
  const stored = await harness.store.registrationsForEvent("default", SHARED_ACCOUNT, 7, 90)
  assert.equal(stored.recipients.length, 1)
  assert.equal(stored.recipients[0].token, "ef".repeat(32))
})
