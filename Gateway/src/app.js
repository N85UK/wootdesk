import { createServer } from "node:http"
import { randomUUID } from "node:crypto"
import {
  GatewayError,
  badRequest,
  notFound,
  rateLimited,
  tooLarge,
  unavailable,
} from "./errors.js"
import { SlidingWindowRateLimiter } from "./rate-limiter.js"
import {
  constantTimeMatches,
  requireBearer,
  requireIdempotencyKey,
  verifyWebhookSignature,
} from "./security.js"
import {
  canonicalHash,
  classifyChatwootEvent,
  deliveryIdentifier,
  validateCreateRegistration,
  validateDeviceID,
  validateUpdateRegistration,
} from "./validation.js"

export function createGatewayHandler({ config, store, sender, logger }) {
  const limiter = new SlidingWindowRateLimiter({
    windowMilliseconds: config.rateLimitWindowMilliseconds,
  })

  return async function handleRequest(request, response) {
    const requestID = randomUUID()
    const startedAt = Date.now()
    let route = "unmatched"
    let status = 500

    try {
      requireSecureTransport(request, config)
      const parsedURL = new URL(request.url ?? "/", "http://gateway.invalid")
      if (parsedURL.search.length > 0) {
        throw badRequest("unsupported_query", "Query parameters are not supported.")
      }

      if (request.method === "GET" && parsedURL.pathname === "/healthz") {
        route = "health"
        status = 200
        return sendJSON(response, status, { status: "ok" })
      }

      if (request.method === "GET" && parsedURL.pathname === "/readyz") {
        route = "readiness"
        const ready = store.isReady && sender.isReady
        status = ready ? 200 : 503
        return sendJSON(response, status, {
          status: ready ? "ready" : "not_ready",
        })
      }

      const rateKey = request.socket.remoteAddress ?? "unknown"
      if (request.method === "POST" && parsedURL.pathname === "/v1/devices") {
        route = "device_create"
        enforceLimit(limiter, `device:${rateKey}`, config.deviceRateLimit)
        requireBearer(request, config.deviceAPIToken)
        const key = requireIdempotencyKey(request)
        const body = await readJSON(request, config)
        const registration = validateCreateRegistration(
          body.value,
          config.apnsTopic,
        )
        const result = await store.createRegistration(registration, {
          scope: "POST:/v1/devices",
          key,
          requestHash: canonicalHash(registration),
          ttlSeconds: config.idempotencyTTLSeconds,
        })
        status = result.status
        return sendJSON(response, status, result.body, result.replayed)
      }

      const deviceMatch = /^\/v1\/devices\/([^/]+)$/.exec(parsedURL.pathname)
      if (deviceMatch && request.method === "PUT") {
        route = "device_update"
        enforceLimit(limiter, `device:${rateKey}`, config.deviceRateLimit)
        requireBearer(request, config.deviceAPIToken)
        const key = requireIdempotencyKey(request)
        const body = await readJSON(request, config)
        const registration = validateUpdateRegistration(
          body.value,
          config.apnsTopic,
          deviceMatch[1],
        )
        const result = await store.updateRegistration(registration, {
          scope: `PUT:/v1/devices/${registration.deviceId}`,
          key,
          requestHash: canonicalHash(registration),
          ttlSeconds: config.idempotencyTTLSeconds,
        })
        status = result.status
        return sendJSON(response, status, result.body, result.replayed)
      }

      if (deviceMatch && request.method === "DELETE") {
        route = "device_delete"
        enforceLimit(limiter, `device:${rateKey}`, config.deviceRateLimit)
        requireBearer(request, config.deviceAPIToken)
        const key = requireIdempotencyKey(request)
        const deviceID = validateDeviceID(deviceMatch[1])
        requireEmptyBody(request)
        const result = await store.deleteRegistration(deviceID, {
          scope: `DELETE:/v1/devices/${deviceID}`,
          key,
          requestHash: canonicalHash({ deviceID }),
          ttlSeconds: config.idempotencyTTLSeconds,
        })
        status = result.status
        return sendEmpty(response, status, result.replayed)
      }

      const webhookPrefix = "/v1/webhooks/chatwoot/"
      if (
        request.method === "POST" &&
        parsedURL.pathname.startsWith(webhookPrefix)
      ) {
        route = "chatwoot_webhook"
        enforceLimit(limiter, `webhook:${rateKey}`, config.webhookRateLimit)
        const suppliedSecret = parsedURL.pathname.slice(webhookPrefix.length)
        if (
          suppliedSecret.includes("/") ||
          !constantTimeMatches(suppliedSecret, config.webhookRouteSecret)
        ) {
          throw notFound()
        }

        const body = await readJSON(request, config)
        if (config.webhookSigningSecret !== undefined) {
          verifyWebhookSignature({
            rawBody: body.raw,
            signature: request.headers["x-chatwoot-signature"],
            timestamp: request.headers["x-chatwoot-timestamp"],
            // Chatwoot signs with the literal bytes of the secret it
            // issued. Decoding it as base64url only ever matched secrets the
            // gateway generated for itself.
            secret: Buffer.from(config.webhookSigningSecret, "utf8"),
            toleranceSeconds: config.webhookSignatureToleranceSeconds,
          })
        }

        const event = classifyChatwootEvent(body.value)
        if (event.action === "ignore") {
          status = 202
          return sendJSON(response, status, { status: "ignored" })
        }

        const identifier = deliveryIdentifier(
          request.headers["x-chatwoot-delivery"],
          event,
        )
        const result = await deliverEvent({
          identifier,
          event,
          config,
          store,
          sender,
          logger,
          requestID,
        })
        status = result.statusCode
        return sendJSON(response, status, result.body)
      }

      throw notFound()
    } catch (error) {
      const publicError = normaliseError(error)
      status = publicError.status
      sendJSON(response, status, {
        error: {
          code: publicError.code,
          message: publicError.message,
        },
      })
    } finally {
      logger.info("HTTP request completed.", {
        requestId: requestID,
        method: request.method,
        route,
        status,
        durationMilliseconds: Date.now() - startedAt,
      })
    }
  }
}

export function createGateway({ config, store, sender, logger }) {
  const server = createServer(
    createGatewayHandler({ config, store, sender, logger }),
  )

  server.requestTimeout = config.requestTimeoutMilliseconds
  server.headersTimeout = config.requestTimeoutMilliseconds
  server.keepAliveTimeout = 5_000
  server.maxRequestsPerSocket = 1_000

  return {
    server,
    async close() {
      await new Promise((resolve) => server.close(resolve))
      await sender.close()
      await store.flush()
    },
  }
}

async function deliverEvent({
  identifier,
  event,
  config,
  store,
  sender,
  logger,
  requestID,
}) {
  const state = await store.beginDelivery(
    identifier,
    config.idempotencyTTLSeconds,
  )
  if (state.complete) {
    return { statusCode: 202, body: { status: "duplicate" } }
  }

  const { recipients: registrations, unroutable } =
    await store.registrationsForEvent(
      event.accountId,
      event.assigneeId,
      config.registrationTTLDays,
    )
  if (registrations.length > config.maxRegistrationsPerEvent) {
    throw unavailable()
  }
  if (unroutable > 0) {
    // Enrolled before the client sent an agent identity. Such a device cannot
    // be matched to an assignee, so it is excluded rather than notified about
    // another agent's conversation. Logged because a silent gap in delivery is
    // harder to diagnose than a noisy one.
    logger.warn("Registrations without an agent identity were not notified.", {
      requestId: requestID,
      deliveryOutcome: "unroutable_registrations",
      count: unroutable,
    })
  }

  const completed = new Set(state.completedDeviceIDs)
  let delivered = 0
  let invalidated = 0
  let failed = 0

  for (const registration of registrations) {
    if (completed.has(registration.deviceId)) {
      continue
    }

    const payload = genericPayload(registration, event)
    const collapseID = `message-${event.accountId}-${event.messageId}`
    try {
      const result = await sender.send(registration, payload, collapseID)
      if (result.accepted) {
        delivered += 1
        await store.markDeviceDelivered(identifier, registration.deviceId)
      } else if (result.invalidToken) {
        invalidated += 1
        await store.removeInvalidRegistration(
          registration.deviceId,
          registration.tokenHash,
        )
        await store.markDeviceDelivered(identifier, registration.deviceId)
      } else {
        failed += 1
      }
    } catch {
      failed += 1
    }
  }

  if (failed > 0) {
    logger.warn("One or more APNs deliveries failed.", {
      requestId: requestID,
      deliveryOutcome: "retryable_failure",
      count: failed,
    })
    return {
      statusCode: 502,
      body: {
        error: {
          code: "apns_delivery_failed",
          message: "One or more notification deliveries failed.",
        },
      },
    }
  }

  await store.completeDelivery(identifier)
  return {
    statusCode: 202,
    body: { status: "accepted", delivered, invalidated },
  }
}

function genericPayload(registration, event) {
  return {
    aps: {
      alert: {
        title: "WootDesk",
        body: "A new message was received.",
      },
      sound: "default",
    },
    profile_id: registration.profileId,
    account_id: event.accountId,
    conversation_id: event.conversationId,
  }
}

async function readJSON(request, config) {
  const contentType = request.headers["content-type"]
  if (
    typeof contentType !== "string" ||
    contentType.split(";", 1)[0].trim().toLowerCase() !== "application/json"
  ) {
    throw badRequest("invalid_content_type", "Content-Type must be application/json.")
  }

  const contentLength = request.headers["content-length"]
  if (typeof contentLength === "string") {
    if (!/^[0-9]+$/.test(contentLength)) {
      throw badRequest("invalid_content_length", "Content-Length is invalid.")
    }
    if (Number(contentLength) > config.maxBodyBytes) {
      throw tooLarge()
    }
  }

  const chunks = []
  let length = 0
  for await (const chunk of request) {
    length += chunk.length
    if (length > config.maxBodyBytes) {
      throw tooLarge()
    }
    chunks.push(chunk)
  }

  if (length === 0) {
    throw badRequest("invalid_json", "A JSON request body is required.")
  }

  const raw = Buffer.concat(chunks)
  try {
    return { raw, value: JSON.parse(raw.toString("utf8")) }
  } catch {
    throw badRequest("invalid_json", "The request body is not valid JSON.")
  }
}

function requireEmptyBody(request) {
  const length = request.headers["content-length"]
  if (
    (length !== undefined && length !== "0") ||
    request.headers["transfer-encoding"] !== undefined
  ) {
    throw badRequest("unexpected_body", "This request must not contain a body.")
  }
}

function requireSecureTransport(request, config) {
  const forwarded = request.headers["x-forwarded-proto"]
  if (
    typeof forwarded === "string" &&
    forwarded.split(",", 1)[0].trim().toLowerCase() === "https"
  ) {
    return
  }

  if (
    config.allowInsecureLocalTest &&
    config.nodeEnvironment !== "production" &&
    isLoopback(request.socket.remoteAddress)
  ) {
    return
  }

  throw new GatewayError(
    426,
    "https_required",
    "HTTPS is required for this service.",
  )
}

function isLoopback(address) {
  return (
    address === "127.0.0.1" ||
    address === "::1" ||
    address === "::ffff:127.0.0.1"
  )
}

function enforceLimit(limiter, key, limit) {
  if (!limiter.allow(key, limit)) {
    throw rateLimited()
  }
}

function normaliseError(error) {
  if (error instanceof GatewayError) {
    return error
  }
  return new GatewayError(
    500,
    "internal_error",
    "The service could not complete the request.",
  )
}

function responseHeaders() {
  return {
    "cache-control": "no-store",
    "content-type": "application/json; charset=utf-8",
    "x-content-type-options": "nosniff",
  }
}

function sendJSON(response, status, body, replayed = false) {
  const encoded = Buffer.from(JSON.stringify(body), "utf8")
  response.writeHead(status, {
    ...responseHeaders(),
    "content-length": String(encoded.length),
    ...(replayed ? { "idempotency-replayed": "true" } : {}),
  })
  response.end(encoded)
}

function sendEmpty(response, status, replayed = false) {
  response.writeHead(status, {
    "cache-control": "no-store",
    "content-length": "0",
    "x-content-type-options": "nosniff",
    ...(replayed ? { "idempotency-replayed": "true" } : {}),
  })
  response.end()
}
