import { randomBytes } from "node:crypto"
import { mkdtemp, rm } from "node:fs/promises"
import { tmpdir } from "node:os"
import { join } from "node:path"
import { Readable } from "node:stream"
import { createGatewayHandler } from "../src/app.js"
import { AtomicRegistrationStore } from "../src/store.js"

export const deviceID = "11111111-1111-4111-8111-111111111111"
export const secondDeviceID = "22222222-2222-4222-8222-222222222222"
export const profileID = "aaaaaaaa-aaaa-4aaa-8aaa-aaaaaaaaaaaa"
export const secondProfileID = "bbbbbbbb-bbbb-4bbb-8bbb-bbbbbbbbbbbb"

export function registration(overrides = {}) {
  return {
    deviceId: deviceID,
    profileId: profileID,
    accountId: 42,
    environment: "development",
    topic: "dev.n85.wootdesk",
    token: "ab".repeat(32),
    ...overrides,
  }
}

export async function createHarness({
  signingSecret,
  send = async () => ({ accepted: true, invalidToken: false, status: 200 }),
  maxBodyBytes = 32_768,
  deviceRateLimit = 100,
  webhookRateLimit = 100,
} = {}) {
  const directory = await mkdtemp(join(tmpdir(), "wootdesk-gateway-test-"))
  const routeSecret = randomBytes(32).toString("base64url")
  const apiToken = randomBytes(32).toString("base64url")
  const config = {
    nodeEnvironment: "test",
    allowInsecureLocalTest: true,
    deviceAPIToken: apiToken,
    webhookRouteSecret: routeSecret,
    webhookSigningSecret: signingSecret,
    webhookSignatureToleranceSeconds: 300,
    apnsTopic: "dev.n85.wootdesk",
    maxBodyBytes,
    requestTimeoutMilliseconds: 5_000,
    rateLimitWindowMilliseconds: 60_000,
    deviceRateLimit,
    webhookRateLimit,
    idempotencyTTLSeconds: 86_400,
    registrationTTLDays: 90,
    maxRegistrationsPerEvent: 100,
  }
  const store = new AtomicRegistrationStore({
    filePath: join(directory, "registrations.json"),
    encryptionKey: randomBytes(32),
  })
  await store.initialise()

  const calls = []
  const sender = {
    isReady: true,
    async send(item, payload, collapseID) {
      calls.push({ item, payload, collapseID })
      return send(item, payload, collapseID)
    },
    async close() {},
  }
  const logs = []
  const logger = {
    info(message, context) {
      logs.push({ level: "info", message, context })
    },
    warn(message, context) {
      logs.push({ level: "warn", message, context })
    },
    error(message, context) {
      logs.push({ level: "error", message, context })
    },
  }
  const handler = createGatewayHandler({ config, store, sender, logger })

  return {
    config,
    store,
    calls,
    logs,
    dataFile: join(directory, "registrations.json"),
    async request(path, options = {}) {
      return invokeHandler(handler, path, options)
    },
    async close() {
      await sender.close()
      await store.flush()
      await rm(directory, { recursive: true, force: true })
    },
  }
}

async function invokeHandler(handler, path, options) {
  const body =
    options.body === undefined ? Buffer.alloc(0) : Buffer.from(options.body)
  const headers = Object.fromEntries(
    Object.entries(options.headers ?? {}).map(([key, value]) => [
      key.toLowerCase(),
      String(value),
    ]),
  )
  if (body.length > 0 && headers["content-length"] === undefined) {
    headers["content-length"] = String(body.length)
  }

  const request = Readable.from(body.length > 0 ? [body] : [])
  request.method = options.method ?? "GET"
  request.url = path
  request.headers = headers
  request.socket = { remoteAddress: "127.0.0.1" }

  let status = 500
  let responseHeaders = {}
  let responseBody = Buffer.alloc(0)
  const response = {
    writeHead(value, values) {
      status = value
      responseHeaders = values
    },
    end(value) {
      if (value !== undefined) {
        responseBody = Buffer.from(value)
      }
    },
  }
  await handler(request, response)
  return new Response(status === 204 ? null : responseBody, {
    status,
    headers: responseHeaders,
  })
}

export function deviceHeaders(harness, key = "request-key-0001") {
  return {
    authorization: `Bearer ${harness.config.deviceAPIToken}`,
    "content-type": "application/json",
    "idempotency-key": key,
  }
}

export async function createDevice(harness, value = registration(), key) {
  return harness.request("/v1/devices", {
    method: "POST",
    headers: deviceHeaders(harness, key),
    body: JSON.stringify(value),
  })
}

export function incomingMessage(overrides = {}) {
  return {
    event: "message_created",
    id: 500,
    message_type: "incoming",
    private: false,
    content: "Invented customer message that must not be forwarded.",
    account: { id: 42, name: "Invented Account" },
    conversation: { id: 700 },
    sender: { name: "Invented Contact", email: "person@example.invalid" },
    ...overrides,
  }
}
