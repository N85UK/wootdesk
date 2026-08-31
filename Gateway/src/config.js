import { isIP } from "node:net"
import { resolve } from "node:path"

const environmentValues = new Set(["development", "production", "test"])

function required(environment, name) {
  const value = environment[name]
  if (typeof value !== "string" || value.length === 0) {
    throw new Error(`${name} is required.`)
  }
  return value
}

function integer(environment, name, fallback, minimum, maximum) {
  const raw = environment[name] ?? String(fallback)
  if (!/^[0-9]+$/.test(raw)) {
    throw new Error(`${name} must be an integer.`)
  }
  const value = Number(raw)
  if (!Number.isSafeInteger(value) || value < minimum || value > maximum) {
    throw new Error(`${name} is outside its supported range.`)
  }
  return value
}

function boolean(environment, name, fallback = false) {
  const raw = environment[name] ?? String(fallback)
  if (raw !== "true" && raw !== "false") {
    throw new Error(`${name} must be true or false.`)
  }
  return raw === "true"
}

function secret(environment, name, { optional = false, exactBytes } = {}) {
  const raw = environment[name]
  if (optional && (raw === undefined || raw === "")) {
    return undefined
  }
  required(environment, name)
  if (!/^[A-Za-z0-9_-]{43,172}$/.test(raw)) {
    throw new Error(`${name} must be an unpadded base64url value.`)
  }
  const decoded = Buffer.from(raw, "base64url")
  if (exactBytes !== undefined && decoded.length !== exactBytes) {
    throw new Error(`${name} must decode to exactly ${exactBytes} bytes.`)
  }
  if (exactBytes === undefined && decoded.length < 32) {
    throw new Error(`${name} must contain at least 32 bytes.`)
  }
  return raw
}

function identifier(environment, name) {
  const value = required(environment, name)
  if (!/^[A-Z0-9]{10}$/.test(value)) {
    throw new Error(`${name} must be a 10-character Apple identifier.`)
  }
  return value
}

export function loadConfig(environment = process.env) {
  const nodeEnvironment = environment.NODE_ENV ?? "production"
  if (!environmentValues.has(nodeEnvironment)) {
    throw new Error("NODE_ENV must be development, production, or test.")
  }

  const allowInsecureLocalTest = boolean(
    environment,
    "ALLOW_INSECURE_LOCAL_TEST",
  )
  if (allowInsecureLocalTest && nodeEnvironment === "production") {
    throw new Error(
      "ALLOW_INSECURE_LOCAL_TEST cannot be enabled in production.",
    )
  }

  const host = environment.HOST ?? "127.0.0.1"
  if (host !== "localhost" && isIP(host) === 0) {
    throw new Error("HOST must be localhost or an IP address.")
  }

  const routeSecret = secret(environment, "WEBHOOK_ROUTE_SECRET")
  const deviceAPIToken = secret(environment, "DEVICE_API_TOKEN")
  const dataEncryptionKey = secret(environment, "DATA_ENCRYPTION_KEY", {
    exactBytes: 32,
  })

  const topic = required(environment, "APNS_BUNDLE_ID")
  if (!/^[A-Za-z0-9.-]{3,255}$/.test(topic) || topic.includes("..")) {
    throw new Error("APNS_BUNDLE_ID is invalid.")
  }

  return Object.freeze({
    nodeEnvironment,
    host,
    port: integer(environment, "PORT", 8080, 1, 65535),
    allowInsecureLocalTest,
    dataFile: resolve(required(environment, "DATA_FILE")),
    dataEncryptionKey: Buffer.from(dataEncryptionKey, "base64url"),
    deviceAPIToken,
    webhookRouteSecret: routeSecret,
    webhookSigningSecret: secret(
      environment,
      "CHATWOOT_WEBHOOK_SIGNING_SECRET",
      { optional: true },
    ),
    webhookSignatureToleranceSeconds: integer(
      environment,
      "CHATWOOT_SIGNATURE_TOLERANCE_SECONDS",
      300,
      30,
      900,
    ),
    apnsTeamID: identifier(environment, "APNS_TEAM_ID"),
    apnsKeyID: identifier(environment, "APNS_KEY_ID"),
    apnsPrivateKeyFile: resolve(
      required(environment, "APNS_PRIVATE_KEY_FILE"),
    ),
    apnsTopic: topic,
    maxBodyBytes: integer(
      environment,
      "MAX_BODY_BYTES",
      32_768,
      1_024,
      262_144,
    ),
    requestTimeoutMilliseconds: integer(
      environment,
      "REQUEST_TIMEOUT_MS",
      10_000,
      1_000,
      60_000,
    ),
    rateLimitWindowMilliseconds: integer(
      environment,
      "RATE_LIMIT_WINDOW_MS",
      60_000,
      1_000,
      3_600_000,
    ),
    deviceRateLimit: integer(
      environment,
      "DEVICE_RATE_LIMIT",
      30,
      1,
      10_000,
    ),
    webhookRateLimit: integer(
      environment,
      "WEBHOOK_RATE_LIMIT",
      300,
      1,
      100_000,
    ),
    idempotencyTTLSeconds: integer(
      environment,
      "IDEMPOTENCY_TTL_SECONDS",
      86_400,
      60,
      604_800,
    ),
    registrationTTLDays: integer(
      environment,
      "REGISTRATION_TTL_DAYS",
      90,
      1,
      365,
    ),
    maxRegistrationsPerEvent: integer(
      environment,
      "MAX_REGISTRATIONS_PER_EVENT",
      500,
      1,
      10_000,
    ),
    shutdownGraceMilliseconds: integer(
      environment,
      "SHUTDOWN_GRACE_MS",
      10_000,
      1_000,
      60_000,
    ),
  })
}
