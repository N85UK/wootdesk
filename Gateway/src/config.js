import { isIP } from "node:net"
import { resolve } from "node:path"
import { normaliseBaseURL } from "./deployments.js"

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

// A secret issued by Chatwoot rather than chosen by the operator.
//
// The strict `secret` rule above demands 32 bytes of base64url, which is right
// for values we generate but wrong here: Chatwoot issues a 24-character
// alphanumeric secret, so requiring our own format made signature
// verification impossible to enable against a real server. The floor is set at
// 16 characters, which is still roughly 80 bits for an alphanumeric value,
// while rejecting anything obviously weak.
function externalSecret(environment, name, { optional = false } = {}) {
  const raw = environment[name]
  if (optional && (raw === undefined || raw === "")) {
    return undefined
  }
  required(environment, name)
  if (!/^[A-Za-z0-9_-]{16,256}$/.test(raw)) {
    throw new Error(
      `${name} must be 16 to 256 characters of letters, digits, underscore or hyphen.`,
    )
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

/**
 * Reads the Chatwoot deployments this gateway serves (N85-64 AC3).
 *
 * Each deployment gets its own route secret and its own signing secret,
 * because the route the request arrived on is the only thing that identifies
 * which Chatwoot sent it. Sharing either between two deployments would
 * recreate the shared routing namespace this exists to remove, so both are
 * rejected here rather than left to be discovered in production.
 *
 * Two shapes are accepted:
 *
 *   - Named deployments, listed in CHATWOOT_DEPLOYMENTS, each configured
 *     through CHATWOOT_DEPLOYMENT_<NAME>_BASE_URL, _ROUTE_SECRET and
 *     optionally _SIGNING_SECRET.
 *   - No deployment settings at all, which yields a single deployment called
 *     "default" built from WEBHOOK_ROUTE_SECRET and
 *     CHATWOOT_WEBHOOK_SIGNING_SECRET.
 *
 * The second shape exists so a gateway can be upgraded in place without
 * changing its configuration, which AC5 depends on: registrations written
 * before this change can only be attributed automatically when there is
 * exactly one deployment to attribute them to.
 */
function deployments(environment) {
  const listed = environment.CHATWOOT_DEPLOYMENTS

  if (listed === undefined || listed === "") {
    return [
      Object.freeze({
        id: "default",
        // No address, so enrolment cannot resolve a deployment by name. With
        // one deployment it does not need to: the app's registration is
        // attributed to the only deployment there is.
        baseUrl: undefined,
        routeSecret: secret(environment, "WEBHOOK_ROUTE_SECRET"),
        signingSecret: externalSecret(
          environment,
          "CHATWOOT_WEBHOOK_SIGNING_SECRET",
          { optional: true },
        ),
        baseUrlConfigured: false,
      }),
    ]
  }

  const names = listed.split(",").map((item) => item.trim())
  const parsed = []
  const seen = new Set()

  for (const name of names) {
    if (!/^[a-z0-9][a-z0-9-]{0,30}$/.test(name)) {
      throw new Error(
        `"${name}" is not a valid deployment identifier. Use lowercase letters, digits and hyphens.`,
      )
    }
    if (seen.has(name)) {
      throw new Error(`Deployment "${name}" is listed more than once. List each deployment once.`)
    }
    seen.add(name)

    const prefix = `CHATWOOT_DEPLOYMENT_${name.toUpperCase().replaceAll("-", "_")}`
    const rawBaseURL = environment[`${prefix}_BASE_URL`]
    if (typeof rawBaseURL !== "string" || rawBaseURL.length === 0) {
      throw new Error(
        `${prefix}_BASE_URL is required. Enrolment uses it to work out which deployment a server profile belongs to.`,
      )
    }
    const baseUrl = normaliseBaseURL(rawBaseURL)
    if (baseUrl === undefined) {
      throw new Error(`${prefix}_BASE_URL is not an http or https address.`)
    }

    parsed.push(
      Object.freeze({
        id: name,
        baseUrl,
        routeSecret: secret(environment, `${prefix}_ROUTE_SECRET`),
        signingSecret: externalSecret(environment, `${prefix}_SIGNING_SECRET`, {
          optional: true,
        }),
        baseUrlConfigured: true,
      }),
    )
  }

  if (parsed.length === 0) {
    throw new Error("CHATWOOT_DEPLOYMENTS lists no deployment.")
  }

  const routeSecrets = new Set()
  const addresses = new Set()
  for (const deployment of parsed) {
    if (routeSecrets.has(deployment.routeSecret)) {
      throw new Error(
        `Deployment "${deployment.id}" shares a route secret with another deployment. Each needs its own, because the route is what identifies the deployment.`,
      )
    }
    routeSecrets.add(deployment.routeSecret)

    if (addresses.has(deployment.baseUrl)) {
      throw new Error(
        `Deployment "${deployment.id}" shares a Chatwoot address with another deployment. Enrolment could not tell them apart.`,
      )
    }
    addresses.add(deployment.baseUrl)
  }

  return parsed
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

  const configuredDeployments = deployments(environment)
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
    deployments: Object.freeze(configuredDeployments),
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
