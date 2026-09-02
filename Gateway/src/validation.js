import { badRequest } from "./errors.js"
import { hash } from "./security.js"

const uuidPattern =
  /^[0-9a-f]{8}-[0-9a-f]{4}-[1-8][0-9a-f]{3}-[89ab][0-9a-f]{3}-[0-9a-f]{12}$/i

function object(value) {
  return value !== null && typeof value === "object" && !Array.isArray(value)
}

function exactKeys(value, requiredKeys, optionalKeys = []) {
  const actual = Object.keys(value)
  const required = new Set(requiredKeys)
  const permitted = new Set([...requiredKeys, ...optionalKeys])
  return (
    actual.every((key) => permitted.has(key)) &&
    [...required].every((key) => actual.includes(key))
  )
}

// The Chatwoot user this device belongs to. Optional so a client built before
// per-agent routing can still enrol rather than being rejected outright. A
// registration without it can never match an assigned conversation, which the
// gateway logs, because guessing would defeat the isolation it provides.
function optionalAgentID(value) {
  if (value === undefined || value === null) {
    return undefined
  }
  if (!Number.isSafeInteger(value) || value < 1) {
    throw badRequest(
      "invalid_registration",
      "agentId must be a positive integer when present.",
    )
  }
  return value
}

function uuid(value, field) {
  if (typeof value !== "string" || !uuidPattern.test(value)) {
    throw badRequest("invalid_registration", `${field} must be a UUID.`)
  }
  return value.toLowerCase()
}

function accountID(value) {
  if (!Number.isSafeInteger(value) || value < 1) {
    throw badRequest(
      "invalid_registration",
      "accountId must be a positive integer.",
    )
  }
  return value
}

function environment(value) {
  if (value !== "development" && value !== "production") {
    throw badRequest(
      "invalid_registration",
      "environment must be development or production.",
    )
  }
  return value
}

function topic(value, expectedTopic) {
  if (value !== expectedTopic) {
    throw badRequest(
      "invalid_registration",
      "topic does not match this gateway deployment.",
    )
  }
  return value
}

function token(value) {
  if (
    typeof value !== "string" ||
    value.length < 64 ||
    value.length > 200 ||
    value.length % 2 !== 0 ||
    !/^[a-fA-F0-9]+$/.test(value)
  ) {
    throw badRequest(
      "invalid_registration",
      "token must be a hexadecimal APNs device token.",
    )
  }
  return value.toLowerCase()
}

export function validateCreateRegistration(value, expectedTopic) {
  if (
    !object(value) ||
    !exactKeys(
      value,
      ["deviceId", "profileId", "accountId", "environment", "topic", "token"],
      ["agentId"],
    )
  ) {
    throw badRequest(
      "invalid_registration",
      "The registration body has missing or unsupported fields.",
    )
  }

  return {
    deviceId: uuid(value.deviceId, "deviceId"),
    profileId: uuid(value.profileId, "profileId"),
    accountId: accountID(value.accountId),
    agentId: optionalAgentID(value.agentId),
    environment: environment(value.environment),
    topic: topic(value.topic, expectedTopic),
    token: token(value.token),
  }
}

export function validateUpdateRegistration(value, expectedTopic, deviceID) {
  if (
    !object(value) ||
    !exactKeys(
      value,
      ["profileId", "accountId", "environment", "topic", "token"],
      ["agentId"],
    )
  ) {
    throw badRequest(
      "invalid_registration",
      "The registration body has missing or unsupported fields.",
    )
  }

  return {
    deviceId: uuid(deviceID, "deviceId"),
    profileId: uuid(value.profileId, "profileId"),
    accountId: accountID(value.accountId),
    agentId: optionalAgentID(value.agentId),
    environment: environment(value.environment),
    topic: topic(value.topic, expectedTopic),
    token: token(value.token),
  }
}

export function validateDeviceID(value) {
  return uuid(value, "deviceId")
}

export function canonicalHash(value) {
  return hash(stableStringify(value))
}

function stableStringify(value) {
  if (Array.isArray(value)) {
    return `[${value.map(stableStringify).join(",")}]`
  }
  if (value !== null && typeof value === "object") {
    const entries = Object.keys(value)
      .sort()
      .map((key) => `${JSON.stringify(key)}:${stableStringify(value[key])}`)
    return `{${entries.join(",")}}`
  }
  return JSON.stringify(value)
}

function positiveInteger(value) {
  return Number.isSafeInteger(value) && value > 0 ? value : undefined
}

export function classifyChatwootEvent(value) {
  if (!object(value)) {
    throw badRequest("invalid_webhook", "The webhook body must be an object.")
  }

  if (value.event !== "message_created") {
    return { action: "ignore", reason: "unsupported_event" }
  }

  const messageType = value.message_type ?? value.message?.message_type
  const isPrivate = value.private ?? value.message?.private
  const isIncoming = messageType === "incoming" || messageType === 0
  if (!isIncoming || isPrivate !== false) {
    return { action: "ignore", reason: "not_incoming" }
  }

  const accountId = positiveInteger(
    value.account?.id ?? value.account_id ?? value.conversation?.account_id,
  )
  const conversationId = positiveInteger(
    value.conversation?.id ??
      value.conversation_id ??
      value.message?.conversation_id,
  )
  const messageId = positiveInteger(value.id ?? value.message?.id)
  // Chatwoot spells the assignee differently across payload shapes and
  // versions, so all three documented forms are accepted. Absent or
  // unassigned leaves this undefined, which the gateway treats as "notify
  // every agent on the account".
  const assigneeId = positiveInteger(
    value.conversation?.meta?.assignee?.id ??
      value.conversation?.assignee_id ??
      value.conversation?.assignee?.id,
  )

  if (accountId === undefined || conversationId === undefined || messageId === undefined) {
    throw badRequest(
      "invalid_webhook",
      "The incoming message routing identifiers are missing.",
    )
  }

  return {
    action: "deliver",
    accountId,
    conversationId,
    messageId,
    assigneeId,
  }
}

export function deliveryIdentifier(header, event) {
  if (header !== undefined) {
    if (
      typeof header !== "string" ||
      header.length < 8 ||
      header.length > 128 ||
      !/^[A-Za-z0-9._:-]+$/.test(header)
    ) {
      throw badRequest(
        "invalid_delivery_identifier",
        "X-Chatwoot-Delivery is invalid.",
      )
    }
    return `header:${header}`
  }
  return `message:${event.accountId}:${event.messageId}`
}
