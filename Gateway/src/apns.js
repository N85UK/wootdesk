import {
  createPrivateKey,
  sign,
} from "node:crypto"
import {
  connect as connectHTTP2,
  constants as http2Constants,
  sensitiveHeaders,
} from "node:http2"

const productionHost = "https://api.push.apple.com"
const developmentHost = "https://api.sandbox.push.apple.com"
const providerTokenLifetimeSeconds = 50 * 60

export class APNSSender {
  #providerToken
  #providerTokenIssuedAt = 0
  #sessions = new Set()

  constructor({
    teamID,
    keyID,
    privateKey,
    connect = connectHTTP2,
    clock = () => Date.now(),
    timeoutMilliseconds = 10_000,
  }) {
    this.teamID = teamID
    this.keyID = keyID
    this.privateKey = createPrivateKey(privateKey)
    this.connect = connect
    this.clock = clock
    this.timeoutMilliseconds = timeoutMilliseconds
  }

  get isReady() {
    return true
  }

  async send(registration, payload, collapseID) {
    const body = Buffer.from(JSON.stringify(payload), "utf8")
    if (body.length > 4_096) {
      throw new Error("The APNs payload exceeds 4,096 bytes.")
    }

    const host =
      registration.environment === "production"
        ? productionHost
        : developmentHost
    const session = this.connect(host)
    this.#sessions.add(session)

    try {
      return await this.#request(
        session,
        registration,
        body,
        collapseID,
      )
    } finally {
      this.#sessions.delete(session)
      session.close()
    }
  }

  async close() {
    for (const session of this.#sessions) {
      session.close()
    }
    this.#sessions.clear()
  }

  #token() {
    const issuedAt = Math.floor(this.clock() / 1000)
    if (
      this.#providerToken === undefined ||
      issuedAt - this.#providerTokenIssuedAt >= providerTokenLifetimeSeconds
    ) {
      this.#providerToken = createProviderToken({
        teamID: this.teamID,
        keyID: this.keyID,
        privateKey: this.privateKey,
        issuedAt,
      })
      this.#providerTokenIssuedAt = issuedAt
    }
    return this.#providerToken
  }

  #request(session, registration, body, collapseID) {
    return new Promise((resolve, reject) => {
      let responseStatus
      let responseBody = ""
      let settled = false

      const finish = (operation, value) => {
        if (settled) {
          return
        }
        settled = true
        clearTimeout(timeout)
        operation(value)
      }

      const stream = session.request({
        ":method": "POST",
        ":path": `/3/device/${registration.token}`,
        authorization: `bearer ${this.#token()}`,
        "apns-topic": registration.topic,
        "apns-push-type": "alert",
        "apns-priority": "10",
        "apns-expiration": "0",
        "apns-collapse-id": collapseID,
        "content-type": "application/json",
        [sensitiveHeaders]: ["authorization"],
      })

      const timeout = setTimeout(() => {
        stream.close(http2Constants.NGHTTP2_CANCEL)
        finish(reject, new Error("The APNs request timed out."))
      }, this.timeoutMilliseconds)

      session.once("error", (error) => finish(reject, error))
      stream.setEncoding("utf8")
      stream.on("response", (headers) => {
        responseStatus = Number(headers[":status"])
      })
      stream.on("data", (chunk) => {
        if (responseBody.length < 4_096) {
          responseBody += chunk
        }
      })
      stream.on("error", (error) => finish(reject, error))
      stream.on("end", () => {
        const reason = parseReason(responseBody)
        const accepted = responseStatus === 200
        const invalidToken =
          responseStatus === 410 ||
          (responseStatus === 400 &&
            [
              "BadDeviceToken",
              "DeviceTokenNotForTopic",
              "Unregistered",
            ].includes(reason))
        finish(resolve, {
          accepted,
          invalidToken,
          status: responseStatus,
          reason,
        })
      })
      stream.end(body)
    })
  }
}

export function createProviderToken({
  teamID,
  keyID,
  privateKey,
  issuedAt,
}) {
  const header = base64urlJSON({ alg: "ES256", kid: keyID })
  const claims = base64urlJSON({ iss: teamID, iat: issuedAt })
  const unsigned = `${header}.${claims}`
  const signature = sign("sha256", Buffer.from(unsigned, "ascii"), {
    key: privateKey,
    dsaEncoding: "ieee-p1363",
  })
  if (signature.length !== 64) {
    throw new Error("The APNs provider signature has an invalid length.")
  }
  return `${unsigned}.${signature.toString("base64url")}`
}

function base64urlJSON(value) {
  return Buffer.from(JSON.stringify(value), "utf8").toString("base64url")
}

function parseReason(value) {
  if (value.length === 0) {
    return undefined
  }
  try {
    const decoded = JSON.parse(value)
    return typeof decoded.reason === "string" ? decoded.reason : undefined
  } catch {
    return undefined
  }
}
