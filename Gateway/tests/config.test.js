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
