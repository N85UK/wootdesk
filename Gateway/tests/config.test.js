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
  assert.equal(config.webhookSigningSecret, "H8kPq2mWvR7nT4xL9cJd3Bza")
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
