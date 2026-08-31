import {
  createCipheriv,
  createDecipheriv,
  createHash,
  createHmac,
  randomBytes,
  timingSafeEqual,
} from "node:crypto"
import { badRequest, unauthorised } from "./errors.js"

export function hash(value) {
  return createHash("sha256").update(value).digest("hex")
}

export function constantTimeMatches(actual, expected) {
  if (typeof actual !== "string" || typeof expected !== "string") {
    return false
  }

  const actualDigest = createHash("sha256").update(actual).digest()
  const expectedDigest = createHash("sha256").update(expected).digest()
  return timingSafeEqual(actualDigest, expectedDigest)
}

export function requireBearer(request, expectedToken) {
  const value = request.headers.authorization
  if (typeof value !== "string" || !value.startsWith("Bearer ")) {
    throw unauthorised()
  }

  const supplied = value.slice("Bearer ".length)
  if (!constantTimeMatches(supplied, expectedToken)) {
    throw unauthorised()
  }
}

export function verifyWebhookSignature({
  rawBody,
  signature,
  timestamp,
  secret,
  toleranceSeconds,
  now = Date.now(),
}) {
  if (typeof signature !== "string" || typeof timestamp !== "string") {
    throw unauthorised()
  }

  if (!/^[0-9]{10}$/.test(timestamp)) {
    throw unauthorised()
  }

  const timestampMilliseconds = Number(timestamp) * 1000
  if (Math.abs(now - timestampMilliseconds) > toleranceSeconds * 1000) {
    throw unauthorised()
  }

  const signatureMatch = /^sha256=([a-f0-9]{64})$/.exec(signature)
  if (!signatureMatch) {
    throw unauthorised()
  }

  const signed = Buffer.concat([
    Buffer.from(`${timestamp}.`, "utf8"),
    rawBody,
  ])
  const expected = createHmac("sha256", secret).update(signed).digest()
  const supplied = Buffer.from(signatureMatch[1], "hex")
  if (!timingSafeEqual(supplied, expected)) {
    throw unauthorised()
  }
}

export function encryptToken(token, key, associatedData) {
  const iv = randomBytes(12)
  const cipher = createCipheriv("aes-256-gcm", key, iv)
  cipher.setAAD(Buffer.from(associatedData, "utf8"))
  const ciphertext = Buffer.concat([
    cipher.update(token, "utf8"),
    cipher.final(),
  ])

  return {
    algorithm: "aes-256-gcm",
    iv: iv.toString("base64url"),
    tag: cipher.getAuthTag().toString("base64url"),
    ciphertext: ciphertext.toString("base64url"),
  }
}

export function decryptToken(envelope, key, associatedData) {
  if (
    envelope?.algorithm !== "aes-256-gcm" ||
    typeof envelope.iv !== "string" ||
    typeof envelope.tag !== "string" ||
    typeof envelope.ciphertext !== "string"
  ) {
    throw new Error("The encrypted registration is invalid.")
  }

  const decipher = createDecipheriv(
    "aes-256-gcm",
    key,
    Buffer.from(envelope.iv, "base64url"),
  )
  decipher.setAAD(Buffer.from(associatedData, "utf8"))
  decipher.setAuthTag(Buffer.from(envelope.tag, "base64url"))
  return Buffer.concat([
    decipher.update(Buffer.from(envelope.ciphertext, "base64url")),
    decipher.final(),
  ]).toString("utf8")
}

export function requireIdempotencyKey(request) {
  const key = request.headers["idempotency-key"]
  if (
    typeof key !== "string" ||
    key.length < 16 ||
    key.length > 128 ||
    !/^[A-Za-z0-9._:-]+$/.test(key)
  ) {
    throw badRequest(
      "invalid_idempotency_key",
      "Idempotency-Key must contain 16 to 128 safe characters.",
    )
  }
  return key
}
