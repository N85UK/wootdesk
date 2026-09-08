import assert from "node:assert/strict"
import { randomBytes } from "node:crypto"
import test from "node:test"
import { loadConfig } from "../src/config.js"

function environment(overrides = {}) {
  const secret = randomBytes(32).toString("base64url")
  return {
    NODE_ENV: "test",
    HOST: "127.0.0.1",
    PORT: "8080",
    ALLOW_INSECURE_LOCAL_TEST: "true",
    DATA_FILE: "/tmp/wootdesk-gateway-invented.json",
    DATA_ENCRYPTION_KEY: randomBytes(32).toString("base64url"),
    DEVICE_API_TOKEN: secret,
    WEBHOOK_ROUTE_SECRET: randomBytes(32).toString("base64url"),
    CHATWOOT_WEBHOOK_SIGNING_SECRET: "",
    APNS_TEAM_ID: "TEAMID1234",
    APNS_KEY_ID: "KEYID12345",
    APNS_PRIVATE_KEY_FILE: "/tmp/invented-apns-key.p8",
    APNS_BUNDLE_ID: "dev.n85.wootdesk",
    ...overrides,
  }
}

test("loadConfig accepts a strict invented test configuration", () => {
  const config = loadConfig(environment())
  assert.equal(config.nodeEnvironment, "test")
  assert.equal(config.dataEncryptionKey.length, 32)
  assert.equal(config.apnsTopic, "dev.n85.wootdesk")
})

test("loadConfig rejects weak secrets", () => {
  assert.throws(
    () => loadConfig(environment({ DEVICE_API_TOKEN: "not-secret" })),
    /DEVICE_API_TOKEN/,
  )
})

test("loadConfig rejects insecure mode in production", () => {
  assert.throws(
    () =>
      loadConfig(
        environment({ NODE_ENV: "production", ALLOW_INSECURE_LOCAL_TEST: "true" }),
      ),
    /cannot be enabled in production/,
  )
})

test("loadConfig accepts the webhook signing secret Chatwoot actually issues", () => {
  // Chatwoot generates this secret, not us, so we do not get to dictate its
  // shape. A real one is 24 alphanumeric characters, roughly 105 bits of
  // entropy, which the earlier 32-byte base64url rule rejected outright. That
  // made signature verification impossible to enable against a real Chatwoot.
  const config = loadConfig(
    environment({ CHATWOOT_WEBHOOK_SIGNING_SECRET: "H8kPq2mWvR7nT4xL9cJd3Bza" }),
  )
  // The secret now lives on the deployment that issued it, because each
  // deployment signs with its own (N85-64 AC3).
  assert.equal(config.deployments[0].signingSecret, "H8kPq2mWvR7nT4xL9cJd3Bza")
})

test("loadConfig still rejects a webhook signing secret that is too short to be safe", () => {
  assert.throws(
    () => loadConfig(environment({ CHATWOOT_WEBHOOK_SIGNING_SECRET: "tooshort" })),
    /CHATWOOT_WEBHOOK_SIGNING_SECRET/,
  )
})

test("loadConfig keeps the strict rule for secrets the operator generates", () => {
  // DEVICE_API_TOKEN and WEBHOOK_ROUTE_SECRET are ours to choose, so the
  // stricter requirement still applies to them.
  assert.throws(
    () => loadConfig(environment({ DEVICE_API_TOKEN: "H8kPq2mWvR7nT4xL9cJd3Bza" })),
    /DEVICE_API_TOKEN/,
  )
})

// N85-64. Deployment configuration.

function multiDeployment(overrides = {}) {
  return environment({
    CHATWOOT_DEPLOYMENTS: "production,review",
    CHATWOOT_DEPLOYMENT_PRODUCTION_BASE_URL: "https://chat.invalid",
    CHATWOOT_DEPLOYMENT_PRODUCTION_ROUTE_SECRET: randomBytes(32).toString("base64url"),
    CHATWOOT_DEPLOYMENT_PRODUCTION_SIGNING_SECRET: "aaaaaaaaaaaaaaaaaaaaaaaa",
    CHATWOOT_DEPLOYMENT_REVIEW_BASE_URL: "https://review.invalid",
    CHATWOOT_DEPLOYMENT_REVIEW_ROUTE_SECRET: randomBytes(32).toString("base64url"),
    CHATWOOT_DEPLOYMENT_REVIEW_SIGNING_SECRET: "bbbbbbbbbbbbbbbbbbbbbbbb",
    WEBHOOK_ROUTE_SECRET: undefined,
    ...overrides,
  })
}

test("a configuration without deployment settings still yields one deployment", () => {
  // AC5 depends on this. A gateway upgraded in place has the old variables and
  // no new ones, and it must keep working with exactly one deployment so its
  // existing registrations can be attributed to something.
  const config = loadConfig(environment())
  assert.equal(config.deployments.length, 1)
  assert.equal(config.deployments[0].id, "default")
  assert.equal(config.deployments[0].baseUrl, undefined)
})

test("the legacy route and signing secrets become the single deployment's", () => {
  const routeSecret = randomBytes(32).toString("base64url")
  const config = loadConfig(
    environment({
      WEBHOOK_ROUTE_SECRET: routeSecret,
      CHATWOOT_WEBHOOK_SIGNING_SECRET: "cccccccccccccccccccccccc",
    }),
  )
  assert.equal(config.deployments[0].routeSecret, routeSecret)
  assert.equal(config.deployments[0].signingSecret, "cccccccccccccccccccccccc")
})

test("named deployments are parsed with their own secrets and addresses", () => {
  const config = loadConfig(multiDeployment())
  assert.deepEqual(
    config.deployments.map((item) => item.id),
    ["production", "review"],
  )
  assert.equal(config.deployments[0].baseUrl, "https://chat.invalid")
  assert.equal(config.deployments[1].baseUrl, "https://review.invalid")
  assert.notEqual(config.deployments[0].routeSecret, config.deployments[1].routeSecret)
})

test("two deployments may not share a route secret", () => {
  // The whole defect is two deployments sharing a routing namespace. A shared
  // route secret would recreate it exactly, while looking configured.
  const shared = randomBytes(32).toString("base64url")
  assert.throws(
    () =>
      loadConfig(
        multiDeployment({
          CHATWOOT_DEPLOYMENT_PRODUCTION_ROUTE_SECRET: shared,
          CHATWOOT_DEPLOYMENT_REVIEW_ROUTE_SECRET: shared,
        }),
      ),
    /route secret/i,
  )
})

test("two deployments may not share a Chatwoot address", () => {
  assert.throws(
    () =>
      loadConfig(
        multiDeployment({
          CHATWOOT_DEPLOYMENT_REVIEW_BASE_URL: "https://chat.invalid/",
        }),
      ),
    /address/i,
  )
})

test("a named deployment must have an address, so enrolment can find it", () => {
  assert.throws(
    () => loadConfig(multiDeployment({ CHATWOOT_DEPLOYMENT_REVIEW_BASE_URL: undefined })),
    /BASE_URL/,
  )
})

test("a deployment address must be an http address", () => {
  assert.throws(
    () => loadConfig(multiDeployment({ CHATWOOT_DEPLOYMENT_REVIEW_BASE_URL: "chat.invalid" })),
    /address/i,
  )
})

test("a deployment identifier must be a simple lowercase name", () => {
  for (const name of ["Production", "pro duction", "prod/uction", "prod!", "-prod"]) {
    assert.throws(
      () => loadConfig(environment({ CHATWOOT_DEPLOYMENTS: name })),
      /identifier/i,
      `accepted ${JSON.stringify(name)}`,
    )
  }
})

test("a deployment listed twice is refused rather than silently deduplicated", () => {
  assert.throws(
    () => loadConfig(multiDeployment({ CHATWOOT_DEPLOYMENTS: "production,production" })),
    /once/i,
  )
})

test("an empty deployment list means none are configured, not a broken name", () => {
  // A .env file commonly carries a variable set to nothing. Treating that as a
  // malformed identifier would refuse to start a gateway that is simply not
  // using named deployments yet.
  const config = loadConfig(environment({ CHATWOOT_DEPLOYMENTS: "" }))
  assert.equal(config.deployments.length, 1)
  assert.equal(config.deployments[0].id, "default")
})
