import assert from "node:assert/strict"
import test from "node:test"
import {
  createDevice,
  createHarness,
  deviceHeaders,
  deviceID,
  registration,
} from "./helpers.js"

test("device endpoints require authentication and HTTPS outside local test", async (t) => {
  const harness = await createHarness()
  t.after(() => harness.close())

  const unauthorised = await harness.request("/v1/devices", {
    method: "POST",
    headers: {
      "content-type": "application/json",
      "idempotency-key": "request-key-0001",
    },
    body: JSON.stringify(registration()),
  })
  assert.equal(unauthorised.status, 401)

  harness.config.allowInsecureLocalTest = false
  const insecure = await harness.request("/healthz")
  assert.equal(insecure.status, 426)
  const proxied = await harness.request("/healthz", {
    headers: { "x-forwarded-proto": "https" },
  })
  assert.equal(proxied.status, 200)
})

test("register, update, and delete never return the APNs token", async (t) => {
  const harness = await createHarness()
  t.after(() => harness.close())

  const created = await createDevice(harness)
  assert.equal(created.status, 201)
  const createdText = await created.text()
  assert.equal(createdText.includes("ab".repeat(32)), false)

  const update = registration({ token: "cd".repeat(32) })
  delete update.deviceId
  const updated = await harness.request(`/v1/devices/${deviceID}`, {
    method: "PUT",
    headers: deviceHeaders(harness, "request-key-0002"),
    body: JSON.stringify(update),
  })
  assert.equal(updated.status, 200)
  assert.equal((await updated.text()).includes("cd".repeat(32)), false)

  const deleted = await harness.request(`/v1/devices/${deviceID}`, {
    method: "DELETE",
    headers: {
      authorization: `Bearer ${harness.config.deviceAPIToken}`,
      "idempotency-key": "request-key-0003",
    },
  })
  assert.equal(deleted.status, 204)
  assert.equal((await harness.store.registrationsForAccount(42, 90)).length, 0)
})

test("device mutations are idempotent and detect key reuse", async (t) => {
  const harness = await createHarness()
  t.after(() => harness.close())

  const first = await createDevice(harness, registration(), "stable-request-key")
  assert.equal(first.status, 201)
  const second = await createDevice(harness, registration(), "stable-request-key")
  assert.equal(second.status, 201)
  assert.equal(second.headers.get("idempotency-replayed"), "true")

  const conflicting = await createDevice(
    harness,
    registration({ accountId: 99 }),
    "stable-request-key",
  )
  assert.equal(conflicting.status, 409)
})

test("device body validation is strict", async (t) => {
  const harness = await createHarness()
  t.after(() => harness.close())
  const body = { ...registration(), api_access_token: "must-not-be-accepted" }
  const response = await createDevice(harness, body)
  assert.equal(response.status, 400)
  assert.equal((await harness.store.registrationsForAccount(42, 90)).length, 0)
})

test("device endpoints enforce body and source rate limits", async (t) => {
  const limitedBodyHarness = await createHarness({ maxBodyBytes: 128 })
  t.after(() => limitedBodyHarness.close())
  const oversized = await createDevice(limitedBodyHarness)
  assert.equal(oversized.status, 413)

  const rateHarness = await createHarness({ deviceRateLimit: 1 })
  t.after(() => rateHarness.close())
  const first = await createDevice(rateHarness, registration(), "rate-key-first-001")
  assert.equal(first.status, 201)
  const second = await createDevice(
    rateHarness,
    registration({ deviceId: "33333333-3333-4333-8333-333333333333" }),
    "rate-key-second-01",
  )
  assert.equal(second.status, 429)
})

test("enrolment without an agent identity is refused", async (t) => {
  // Accepting it returned 201 and left the device excluded from every
  // conversation assigned to its own agent, with only a warn line to say so.
  // The app then reported remote delivery as enabled while receiving nothing.
  // Refusing makes the failure immediate and visible instead.
  const harness = await createHarness()
  t.after(() => harness.close())

  const body = registration()
  delete body.agentId
  const response = await createDevice(harness, body, "no-agent-identity-0001")

  assert.equal(response.status, 400)
  const payload = await response.json()
  assert.equal(payload.error.code, "invalid_registration")
  assert.match(payload.error.message, /agentId is required/)
  assert.equal((await harness.store.registrationsForAccount(42, 90)).length, 0)
})

test("enrolment with a non-positive agent identity is refused", async (t) => {
  const harness = await createHarness()
  t.after(() => harness.close())

  const response = await createDevice(
    harness,
    registration({ agentId: 0 }),
    "bad-agent-identity-0001",
  )

  assert.equal(response.status, 400)
  assert.equal((await response.json()).error.code, "invalid_registration")
  assert.equal((await harness.store.registrationsForAccount(42, 90)).length, 0)
})
